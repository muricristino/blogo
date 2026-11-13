use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const USAGE: &str = "usage:
  blogo list
  blogo get <slug> [--out dir]       writes <dir>/post.md, hero.json and the post's images
  blogo show <slug>                  prints the post as JSON
  blogo push <dir|file.md> [--hero hero.json] [--slug s] [--language pt-BR] [--prune]
  blogo publish <slug>
  blogo unpublish <slug>

push reads <dir>/post.md, or the file given; hero.json beside it is sent when present.
Images are written in the markdown as ![alt](name.png) on a line of their own, the
name being a path relative to the markdown file. push uploads the ones whose bytes
the server does not have yet; --prune deletes server images the markdown no longer uses.

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
        "show" => {
            let slug = one_slug(rest)?;
            Client::from_env()?.call("GET", &post_path(&slug), None)
        }
        "get" => get(rest),
        "publish" | "unpublish" => {
            let slug = one_slug(rest)?;
            let path = format!("{}/{command}", post_path(&slug));
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

fn post_path(slug: &str) -> String {
    format!("/api/posts/{}", encode(slug))
}

fn image_path(slug: &str, name: &str) -> String {
    let encoded: Vec<String> = name.split('/').map(encode).collect();
    format!("{}/images/{}", post_path(slug), encoded.join("/"))
}

fn get(rest: &[String]) -> Result<Value, Failure> {
    let mut slug = None;
    let mut out = None;
    let mut it = rest.iter();
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--out" => {
                out = Some(PathBuf::from(
                    it.next()
                        .ok_or_else(|| fail("usage", "--out needs a value"))?,
                ))
            }
            a if a.starts_with('-') => return Err(fail("usage", format!("unknown flag '{a}'"))),
            a if slug.is_none() => slug = Some(a.to_string()),
            _ => return Err(fail("usage", USAGE)),
        }
    }
    let slug = slug.ok_or_else(|| fail("usage", USAGE))?;
    let dir = out.unwrap_or_else(|| PathBuf::from(&slug));
    let client = Client::from_env()?;

    let shown = client.call("GET", &post_path(&slug), None)?;
    if !is_ok(&shown) {
        return Ok(shown);
    }
    let post = &shown["post"];
    let markdown = post["markdown"].as_str().unwrap_or_default();

    fs::create_dir_all(&dir).map_err(|e| fail("file", format!("{}: {e}", dir.display())))?;
    let mut files = vec![];

    write_file(&dir.join("post.md"), markdown.as_bytes())?;
    files.push("post.md".to_string());

    let hero_file = dir.join("hero.json");
    if post["hero"].is_object() {
        let text = serde_json::to_string_pretty(&post["hero"]).unwrap_or_default() + "\n";
        write_file(&hero_file, text.as_bytes())?;
        files.push("hero.json".to_string());
    } else if hero_file.exists() {
        fs::remove_file(&hero_file)
            .map_err(|e| fail("file", format!("{}: {e}", hero_file.display())))?;
    }

    let listed = client.call("GET", &format!("{}/images", post_path(&slug)), None)?;
    if !is_ok(&listed) {
        return Ok(listed);
    }
    for image in listed["images"].as_array().cloned().unwrap_or_default() {
        let name = image["name"].as_str().unwrap_or_default().to_string();
        let target = safe_join(&dir, &name)?;
        let local_matches = fs::read(&target)
            .map(|bytes| sha256_hex(&bytes) == image["digest"].as_str().unwrap_or_default())
            .unwrap_or(false);
        if !local_matches {
            let fetched = client.call("GET", &image_path(&slug, &name), None)?;
            if !is_ok(&fetched) {
                return Ok(fetched);
            }
            let bytes = BASE64
                .decode(fetched["image"]["data"].as_str().unwrap_or_default())
                .map_err(|e| fail("image", format!("{name}: not valid base64: {e}")))?;
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| fail("file", format!("{}: {e}", parent.display())))?;
            }
            write_file(&target, &bytes)?;
        }
        files.push(name);
    }

    Ok(json!({
        "ok": true,
        "slug": slug,
        "status": post["status"],
        "dir": dir.display().to_string(),
        "files": files,
        "preview_url": post["preview_url"],
        "url": post["url"],
    }))
}

fn push(rest: &[String]) -> Result<Value, Failure> {
    let mut target = None;
    let mut hero = None;
    let mut slug = None;
    let mut language = None;
    let mut prune = false;

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
            "--prune" => prune = true,
            a if a.starts_with('-') => return Err(fail("usage", format!("unknown flag '{a}'"))),
            a if target.is_none() => target = Some(PathBuf::from(a)),
            _ => return Err(fail("usage", USAGE)),
        }
    }

    let target = target.ok_or_else(|| fail("usage", USAGE))?;
    let file = if target.is_dir() {
        target.join("post.md")
    } else {
        target
    };
    let base = file
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."));
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

    let mut local = vec![];
    for name in image_refs(&markdown) {
        if name.is_empty() {
            continue;
        }
        if name.contains("://") {
            return Err(fail(
                "image",
                format!("{name}: images are uploaded files, write a path relative to the markdown"),
            ));
        }
        let path = safe_join(&base, &name)?;
        let bytes =
            fs::read(&path).map_err(|e| fail("image", format!("{}: {e}", path.display())))?;
        local.push((name, bytes));
    }

    let hero = hero.or_else(|| Some(base.join("hero.json")).filter(|p| p.exists()));
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

    let client = Client::from_env()?;
    let images_url = format!("{}/images", post_path(&slug));
    let listed = client.call("GET", &images_url, None)?;
    let exists = is_ok(&listed);

    // A post that exists gets its images before its text, so a published
    // article never points at an image that is still on its way. A new post has
    // nothing to hang images on until the text creates it.
    let mut saved = None;
    if !exists {
        let response = client.call("PUT", &post_path(&slug), Some(body.clone()))?;
        if !is_ok(&response) {
            return Ok(response);
        }
        saved = Some(response);
    }

    let remote: Vec<Value> = if exists {
        listed["images"].as_array().cloned().unwrap_or_default()
    } else {
        vec![]
    };

    let mut uploaded = vec![];
    let mut unchanged = vec![];
    for (name, bytes) in &local {
        let hash = sha256_hex(bytes);
        let same = remote.iter().any(|r| {
            r["name"].as_str() == Some(name.as_str())
                && (r["digest"].as_str() == Some(hash.as_str())
                    || r["source_digest"].as_str() == Some(hash.as_str()))
        });
        if same {
            unchanged.push(name.clone());
            continue;
        }
        let response = client.call(
            "PUT",
            &image_path(&slug, name),
            Some(json!({"data": BASE64.encode(bytes)})),
        )?;
        if !is_ok(&response) {
            return Ok(response);
        }
        uploaded.push(name.clone());
    }

    let saved = match saved {
        Some(response) => response,
        None => {
            let response = client.call("PUT", &post_path(&slug), Some(body))?;
            if !is_ok(&response) {
                return Ok(response);
            }
            response
        }
    };

    let referenced: BTreeSet<&str> = local.iter().map(|(n, _)| n.as_str()).collect();
    let unused: Vec<String> = remote
        .iter()
        .filter_map(|r| r["name"].as_str())
        .filter(|n| !referenced.contains(n))
        .map(String::from)
        .collect();

    let mut deleted = vec![];
    if prune {
        for name in &unused {
            let response = client.call("DELETE", &image_path(&slug, name), None)?;
            if !is_ok(&response) {
                return Ok(response);
            }
            deleted.push(name.clone());
        }
    }

    let changed =
        saved["changed"].as_bool().unwrap_or(true) || !uploaded.is_empty() || !deleted.is_empty();
    let post = &saved["post"];

    Ok(json!({
        "ok": true,
        "created": saved["created"],
        "changed": changed,
        "slug": post["slug"],
        "status": post["status"],
        "images": {
            "uploaded": uploaded,
            "unchanged": unchanged,
            "deleted": deleted,
            "unused": if prune { vec![] } else { unused },
        },
        "preview_url": post["preview_url"],
        "url": post["url"],
    }))
}

fn is_ok(v: &Value) -> bool {
    v.get("ok").and_then(Value::as_bool).unwrap_or(false)
}

fn write_file(path: &Path, bytes: &[u8]) -> Result<(), Failure> {
    fs::write(path, bytes).map_err(|e| fail("file", format!("{}: {e}", path.display())))
}

fn safe_join(base: &Path, name: &str) -> Result<PathBuf, Failure> {
    let unsafe_name = name.starts_with('/')
        || name
            .split('/')
            .any(|seg| seg.is_empty() || seg == "." || seg == "..");
    if unsafe_name {
        return Err(fail(
            "image",
            format!("{name}: an image name is a plain relative path, like prints/tela.png"),
        ));
    }
    Ok(base.join(name))
}

fn sha256_hex(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

fn image_refs(markdown: &str) -> Vec<String> {
    let mut refs = vec![];
    let mut in_code = false;
    let mut in_fence = false;
    let mut lines = markdown.lines().peekable();

    if lines.peek().map(|l| l.trim()) == Some("---") {
        lines.next();
        for line in lines.by_ref() {
            if line.trim() == "---" {
                break;
            }
        }
    }

    let mut previous_blank = true;
    for line in lines {
        let trimmed = line.trim();
        if in_code {
            in_code = !line.starts_with("```");
        } else if in_fence {
            in_fence = trimmed != ":::";
        } else if line.starts_with("```") && previous_blank {
            in_code = true;
        } else if line.starts_with(":::") && previous_blank {
            in_fence = true;
        } else if let Some(src) = image_line(line) {
            if previous_blank && !refs.contains(&src) {
                refs.push(src);
            }
        }
        previous_blank = trimmed.is_empty();
    }
    refs
}

fn image_line(line: &str) -> Option<String> {
    let rest = line.strip_prefix("![")?;
    let line_end = rest.trim_end();
    let inner = line_end.strip_suffix(')')?;
    let open = inner.rfind("](")?;
    let src = &inner[open + 2..];
    if src
        .chars()
        .any(|c| c.is_whitespace() || c == '(' || c == ')')
    {
        return None;
    }
    Some(src.to_string())
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
            ("DELETE", _) => self
                .agent
                .delete(&url)
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
            .with_config()
            .limit(64 * 1024 * 1024)
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_images_on_their_own_line() {
        let md = "---\ntitulo: x\nendereco: x\n---\n\nTexto.\n\n![A rua](prints/rua.png)\n+ legenda\n\n![](b.png)\n";
        assert_eq!(image_refs(md), vec!["prints/rua.png", "b.png"]);
    }

    #[test]
    fn ignores_images_inside_text_code_and_fences() {
        let md = "Veja ![x](a.png) aqui.\n\n```md\n![x](b.png)\n```\n\n:::aviso note\n![x](c.png)\n:::\n\nlinha\n![x](d.png)\n";
        assert!(image_refs(md).is_empty());
    }

    #[test]
    fn alt_text_may_hold_brackets() {
        assert_eq!(
            image_line("![O menu [pausa]](a.png)").as_deref(),
            Some("a.png")
        );
        assert_eq!(image_line("![x](a b.png)"), None);
    }

    #[test]
    fn names_cannot_climb_out() {
        let base = Path::new("/tmp/post");
        assert!(safe_join(base, "../x.png").is_err());
        assert!(safe_join(base, "/etc/x.png").is_err());
        assert!(safe_join(base, "a//b.png").is_err());
        assert_eq!(
            safe_join(base, "prints/a.png").ok(),
            Some(base.join("prints/a.png"))
        );
    }

    #[test]
    fn hashes_like_the_server() {
        assert_eq!(
            sha256_hex(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn image_names_are_encoded_per_segment() {
        assert_eq!(
            image_path("um-post", "prints/tela 1.png"),
            "/api/posts/um-post/images/prints/tela%201.png"
        );
    }
}
