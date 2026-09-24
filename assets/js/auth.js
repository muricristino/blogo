// The sign-in page, when Clerk is configured.
//
// The login happens here, in the browser, with Clerk's own SDK — the server
// never sees a password and never talks to Clerk to sign anyone in. What it
// gets is a short-lived session token, which it verifies against the
// instance's JWKS. This is the same division of labour codo and webo use.

const mount = document.getElementById("clerk-signin")

// A publishable key is pk_test_ / pk_live_ followed by the base64 of the
// instance's host. Taking the host from the key means the SDK is loaded from
// the same instance that will verify the token.
function instanceHost(publishableKey) {
  try {
    return atob(publishableKey.replace(/^pk_(test|live)_/, "")).replace(/\$$/, "")
  } catch {
    return null
  }
}

function loadClerk(publishableKey) {
  const host = instanceHost(publishableKey)
  if (!host) return Promise.reject(new Error("chave publicável inválida"))

  return new Promise((resolve, reject) => {
    const el = document.createElement("script")
    el.async = true
    el.crossOrigin = "anonymous"
    el.dataset.clerkPublishableKey = publishableKey
    el.src = `https://${host}/npm/@clerk/clerk-js@5/dist/clerk.browser.js`
    el.onload = () => resolve(window.Clerk)
    el.onerror = () => reject(new Error("o clerk-js não carregou"))
    document.head.appendChild(el)
  })
}

// Clerk computes its own shades from concrete colours: it understands neither
// `var()` nor a media query, so the theme has to be resolved here and handed
// over already decided. Passing the light values unconditionally is what put
// dark text on a dark card and a white input in the middle of a dark page.
function dark() {
  const set = document.documentElement.getAttribute("data-theme")
  return set ? set === "dark" : matchMedia("(prefers-color-scheme: dark)").matches
}

// The same tokens app.css defines, written out — see the `:root[data-theme]`
// blocks there. A colour that drifts from them shows up as a login that does
// not look like the rest of the site.
const palette = () =>
  dark()
    ? {
        colorPrimary: "#2563eb",
        colorText: "#eef4ff",
        colorTextSecondary: "rgba(255,255,255,.62)",
        colorBackground: "transparent",
        colorInputBackground: "rgba(255,255,255,.05)",
        colorInputText: "#eef4ff",
        colorNeutral: "#ffffff",
        colorDanger: "#fb7185",
        colorSuccess: "#34d399",
        colorWarning: "#fbbf24"
      }
    : {
        colorPrimary: "#2563eb",
        colorText: "#101828",
        colorTextSecondary: "#626c7a",
        colorBackground: "transparent",
        colorInputBackground: "#ffffff",
        colorInputText: "#101828",
        colorNeutral: "#101828",
        colorDanger: "#be123c",
        colorSuccess: "#047857",
        colorWarning: "#b45309"
      }

// The border, the divider and the muted labels, per theme. These are literal
// because Clerk's `appearance` is passed to its own style engine, not written
// into this document — `var(--line)` handed to it resolves against wherever it
// injects the rule, which is not somewhere our `:root` reaches. Same reason the
// social card carries its own stylesheet; see `lib/blogo/card.ex`.
const edges = () =>
  dark()
    ? { line: "rgba(147,197,253,.15)", muted: "rgba(255,255,255,.44)", field: "rgba(255,255,255,.05)", ink: "#eef4ff" }
    : { line: "#e6ebf3", muted: "#8c95a1", field: "rgba(255,255,255,.7)", ink: "#101828" }

// Rebuilt on demand rather than fixed at module load: the theme can change
// after the component is mounted, and a palette captured once would keep the
// login in whichever theme the page happened to open in.
function buildAppearance() {
  const e = edges()

  return {
    variables: {
      ...palette(),
      borderRadius: "11px",
      fontFamily: "'IBM Plex Sans', ui-sans-serif, system-ui, sans-serif"
    },
    elements: {
      // Clerk ships its own card, and mounted inside ours that reads as a card
      // in a card. The page already says where you are and why.
      // clerk-js v5 wraps the card in a `cardBox` that carries the width and the
      // shadow; styling only `card` leaves that box at its own size, which is
      // what pushed the form outside ours.
      rootBox: { width: "100%" },
      cardBox: { width: "100%", maxWidth: "100%", boxShadow: "none", border: "0" },
      // The social button is an outlined box, and its border comes from the
      // neutral shade Clerk derives — which lands on almost nothing over a dark
      // card. It is stated instead of computed.
      socialButtonsBlockButton: {
        borderColor: e.line,
        color: e.ink,
        backgroundColor: e.field
      },
      dividerLine: { backgroundColor: e.line },
      dividerText: { color: e.muted },
      formFieldLabel: { color: e.muted },
      formFieldInput: { borderColor: e.line },
      card: { boxShadow: "none", border: "0", padding: "0", background: "transparent" },
      header: { display: "none" },
      footer: { display: "none" },
      formButtonPrimary: { fontSize: "14px", textTransform: "none" }
    }
  }
}

// O componente do Clerk vem com controles de 30px, e a regra do projeto é 44
// sob toque (CLAUDE.md). O `appearance` não tem media query, então isto entra
// como folha de estilo — as classes `cl-` são a API pública deles para isso.
const TOUCH_TARGETS = `
@media (pointer: coarse) {
  .cl-socialButtonsBlockButton,
  .cl-formButtonPrimary,
  .cl-formFieldInput,
  .cl-footerActionLink,
  .cl-formFieldInputShowPasswordButton {
    min-height: 44px;
  }
  .cl-formFieldInputShowPasswordButton { min-width: 44px; }
}`

function installTouchTargets() {
  const style = document.createElement("style")
  style.textContent = TOUCH_TARGETS
  document.head.appendChild(style)
}

// The interface around it is in Portuguese; leaving the component in English
// makes the login look like it belongs to somebody else's site.
const localization = {
  socialButtonsBlockButton: "Continuar com {{provider|titleize}}",
  dividerText: "ou",
  formFieldLabel__emailAddress: "E-mail",
  formFieldLabel__password: "Senha",
  formFieldInputPlaceholder__emailAddress: "seu@email.com",
  formButtonPrimary: "Continuar",
  signIn: {
    start: { title: "", subtitle: "", actionText: "", actionLink: "" },
    password: { title: "Digite sua senha", subtitle: "" },
    emailCode: { title: "Confira seu e-mail", subtitle: "", formTitle: "Código de verificação" }
  },
  footerActionLink__useAnotherMethod: "Usar outro método",
  backButton: "Voltar"
}

function fail(message) {
  const box = document.getElementById("clerk-error")
  if (!box) return
  box.textContent = message
  box.hidden = false
}

function mountSignIn(Clerk, mount) {
  Clerk.mountSignIn(mount, {
    appearance: buildAppearance(),
    afterSignInUrl: window.location.pathname,
    afterSignUpUrl: window.location.pathname
  })
}

// Clerk resolves its shades once, when it is given an appearance, so a theme
// change afterwards leaves the component in the old one — dark text on a dark
// card, which is the bug this page had to begin with.
//
// `__unstable__updateProps` looks like the way to re-apply one. It exists, it
// accepts the call and it returns without throwing — and it changes nothing.
// An API that fails silently is worse than one that is missing, because the
// obvious fallback (catch and remount) never runs. So the component is simply
// mounted again, which is the only thing that demonstrably works.
//
// Remounting resets the flow, so it only happens while the form is untouched.
// Someone who has already typed an address is mid-login, and sending them back
// to the start to fix a colour is the worse trade; their card stays in the
// previous theme until the page is reloaded.
function watchTheme(Clerk, mount) {
  let current = dark()

  const untouched = () =>
    [...mount.querySelectorAll("input")].every(i => i.value === "")

  const reapply = () => {
    if (dark() === current) return
    current = dark()

    if (Clerk.user || !untouched()) return

    Clerk.unmountSignIn(mount)
    mountSignIn(Clerk, mount)
  }

  // Two separate paths: the site's own toggle writes `data-theme` on <html>,
  // and with no preference stored the system setting decides.
  new MutationObserver(reapply).observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["data-theme"]
  })

  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", reapply)
}

async function start() {
  if (!mount) return

  const publishableKey = mount.dataset.publishableKey
  const sessionPath = mount.dataset.sessionPath

  let Clerk
  try {
    Clerk = await loadClerk(publishableKey)
    await Clerk.load({ appearance: buildAppearance(), localization })
  } catch (error) {
    fail("Não foi possível carregar o login. Verifique a conexão e recarregue.")
    return
  }

  watchTheme(Clerk, mount)

  // Already signed in with Clerk but no Phoenix session yet — which is what a
  // reload of this page looks like. Exchange the token instead of showing a
  // form that asks for a login that already happened.
  if (Clerk.user) return exchange(Clerk, sessionPath)

  mount.innerHTML = ""
  installTouchTargets()
  // A altura mínima existe só para a caixa não saltar durante o carregamento.
  mount.style.minHeight = "auto"
  mountSignIn(Clerk, mount)

  Clerk.addListener(({ user }) => {
    if (user) exchange(Clerk, sessionPath)
  })
}

// The token proves who this is; the server checks it and answers with where to
// go. The token is not stored anywhere on this side beyond this call.
async function exchange(Clerk, sessionPath) {
  let token
  try {
    token = await Clerk.session.getToken()
  } catch {
    fail("A sessão expirou. Recarregue a página.")
    return
  }

  const csrf = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

  const response = await fetch(sessionPath, {
    method: "POST",
    headers: { "content-type": "application/json", "x-csrf-token": csrf },
    body: JSON.stringify({ token })
  })

  const body = await response.json().catch(() => ({}))

  if (response.ok && body.redirect) {
    window.location.href = body.redirect
  } else {
    // Signed in with Clerk, but not allowed here. Signing out locally stops
    // the page from looping straight back into the exchange.
    await Clerk.signOut().catch(() => {})
    fail(body.error || "Esta conta não tem acesso ao blogo.")
  }
}

start()
