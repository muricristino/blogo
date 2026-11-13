use serde_json::{Value, json};
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "usage:
  blogo list
  blogo get <slug>
  blogo push <file.md> [--hero hero.json] [--slug s] [--language pt-BR]
  blogo publish <slug>
  blogo unpublish <slug>

config: ~/.config/blogo/config (url = ..., token = ...), overridden by BLOGO_URL / BLOGO_TOKEN";

struct Failure {
    code: String,
    message: String,
}

fn fail(code: &str, message: impl Into<String>) -> Failure {
    Failure {
        code: code.into(),
        message: message.into(),
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let result = run(&args);
    let (body, ok) = match result {
        Ok(v) => {
            let ok = v.get("ok").and_then(Value::as_bool).unwrap_or(false);
            (v, ok)
        }
        Err(f) => (
            json!({"ok": false, "error": {"code": f.code, "message": f.message}}),
            false,
        ),
    };
    println!(
        "{}",
        serde_json::to_string_pretty(&body).unwrap_or_default()
    );
    if ok {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}

fn run(args: &[String]) -> Result<Value, Failure> {
    let Some(command) = args.first() else {
        return Err(fail("usage", USAGE));
    };
    let rest = &args[1..];

    match command.as_str() {
        "help" | "-h" | "--help" => Ok(json!({"ok": true, "usage": USAGE})),
        "list" | "ls" => Client::from_env()?.call("GET", "/api/posts", None),
        "get" => {
            let slug = one_slug(rest)?;
            Client::from_env()?.call("GET", &format!("/api/posts/{}", encode(&slug)), None)
        }
        "publish" | "unpublish" => {
            let slug = one_slug(rest)?;
            let path = format!("/api/posts/{}/{command}", encode(&slug));
            Client::from_env()?.call("POST", &path, None)
        }
        "push" => push(rest),
        other => Err(fail(
            "usage",
            format!("unknown command '{other}'\n\n{USAGE}"),
        )),
    }
}

fn one_slug(rest: &[String]) -> Result<String, Failure> {
    match rest {
        [slug] if !slug.starts_with('-') => Ok(slug.clone()),
        _ => Err(fail("usage", USAGE)),
    }
}

fn push(rest: &[String]) -> Result<Value, Failure> {
    let mut file = None;
    let mut hero = None;
    let mut slug = None;
    let mut language = None;

    let mut it = rest.iter();
    while let Some(arg) = it.next() {
        let mut value = |name: &str| {
            it.next()
                .cloned()
                .ok_or_else(|| fail("usage", format!("{name} needs a value")))
        };
        match arg.as_str() {
            "--hero" => hero = Some(PathBuf::from(value("--hero")?)),
            "--slug" => slug = Some(value("--slug")?),
            "--language" => language = Some(value("--language")?),
            a if a.starts_with('-') => return Err(fail("usage", format!("unknown flag '{a}'"))),
            a if file.is_none() => file = Some(PathBuf::from(a)),
            _ => return Err(fail("usage", USAGE)),
        }
    }

    let file = file.ok_or_else(|| fail("usage", USAGE))?;
    let markdown =
        fs::read_to_string(&file).map_err(|e| fail("file", format!("{}: {e}", file.display())))?;

    let slug = slug
        .or_else(|| front_matter_slug(&markdown))
        .ok_or_else(|| {
            fail(
                "usage",
                "no slug: pass --slug or set 'endereco:' in the front matter",
            )
        })?;

    let mut body = json!({"markdown": markdown});
    if let Some(path) = hero {
        let text = fs::read_to_string(&path)
            .map_err(|e| fail("file", format!("{}: {e}", path.display())))?;
        let value: Value = serde_json::from_str(&text)
            .map_err(|e| fail("hero", format!("{}: not valid JSON: {e}", path.display())))?;
        body["hero"] = value;
    }
    if let Some(lang) = language {
        body["language"] = json!(lang);
    }

    Client::from_env()?.call("PUT", &format!("/api/posts/{}", encode(&slug)), Some(body))
}

fn front_matter_slug(markdown: &str) -> Option<String> {
    let mut lines = markdown.lines();
    if lines.next()?.trim() != "---" {
        return None;
    }
    lines
        .take_while(|l| l.trim() != "---")
        .find_map(|l| l.strip_prefix("endereco:"))
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

fn encode(segment: &str) -> String {
    segment
        .bytes()
        .map(|b| match b {
            b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                (b as char).to_string()
            }
            _ => format!("%{b:02X}"),
        })
        .collect()
}

struct Client {
    url: String,
    token: String,
    agent: ureq::Agent,
}

impl Client {
    fn from_env() -> Result<Self, Failure> {
        let file = read_config();
        let pick = |env: &str, key: &str| {
            std::env::var(env)
                .ok()
                .filter(|v| !v.is_empty())
                .or_else(|| file.iter().find(|(k, _)| k == key).map(|(_, v)| v.clone()))
        };
        let url = pick("BLOGO_URL", "url").ok_or_else(|| {
            fail(
                "config",
                "no url: set 'url' in ~/.config/blogo/config or BLOGO_URL",
            )
        })?;
        let token = pick("BLOGO_TOKEN", "token").ok_or_else(|| {
            fail(
                "config",
                "no token: set 'token' in ~/.config/blogo/config or BLOGO_TOKEN",
            )
        })?;
        let agent = ureq::Agent::config_builder()
            .http_status_as_error(false)
            .build()
            .into();
        Ok(Client {
            url: url.trim_end_matches('/').to_string(),
            token,
            agent,
        })
    }

    fn call(&self, method: &str, path: &str, body: Option<Value>) -> Result<Value, Failure> {
        let url = format!("{}{path}", self.url);
        let auth = format!("Bearer {}", self.token);
        let sent = match (method, body) {
            ("GET", _) => self
                .agent
                .get(&url)
                .header("Authorization", &auth)
                .header("Accept", "application/json")
                .call(),
            ("PUT", Some(b)) => self
                .agent
                .put(&url)
                .header("Authorization", &auth)
                .header("Accept", "application/json")
                .header("Content-Type", "application/json")
                .send(b.to_string()),
            _ => self
                .agent
                .post(&url)
                .header("Authorization", &auth)
                .header("Accept", "application/json")
                .send_empty(),
        };

        let mut response = sent.map_err(|e| fail("network", format!("{url}: {e}")))?;
        let status = response.status().as_u16();
        let text = response
            .body_mut()
            .read_to_string()
            .map_err(|e| fail("network", format!("{url}: {e}")))?;

        match serde_json::from_str::<Value>(&text) {
            Ok(mut v) if v.get("ok").is_some() => {
                if let Some(obj) = v.as_object_mut() {
                    obj.insert("http_status".into(), json!(status));
                }
                Ok(v)
            }
            _ => {
                let excerpt: String = text.chars().take(300).collect();
                Err(fail(
                    &format!("http_{status}"),
                    format!("{url}: unexpected response: {excerpt}"),
                ))
            }
        }
    }
}

fn read_config() -> Vec<(String, String)> {
    let Some(home) = std::env::var_os("HOME") else {
        return vec![];
    };
    let path = PathBuf::from(home).join(".config/blogo/config");
    let Ok(text) = fs::read_to_string(path) else {
        return vec![];
    };
    text.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .filter_map(|l| l.split_once('='))
        .map(|(k, v)| (k.trim().to_string(), v.trim().trim_matches('"').to_string()))
        .collect()
}
