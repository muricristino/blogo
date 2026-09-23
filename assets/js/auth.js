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

// Clerk derives its own shades from concrete colours, so these are the hex
// values behind the tokens rather than the `var()` the stylesheet uses.
const appearance = {
  variables: {
    colorPrimary: "#2563eb",
    colorText: "#101828",
    colorTextSecondary: "#626c7a",
    colorBackground: "transparent",
    colorInputBackground: "#ffffff",
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
    card: { boxShadow: "none", border: "0", padding: "0", background: "transparent" },
    header: { display: "none" },
    footer: { display: "none" },
    formButtonPrimary: { fontSize: "14px", textTransform: "none" }
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

async function start() {
  if (!mount) return

  const publishableKey = mount.dataset.publishableKey
  const sessionPath = mount.dataset.sessionPath

  let Clerk
  try {
    Clerk = await loadClerk(publishableKey)
    await Clerk.load({ appearance, localization })
  } catch (error) {
    fail("Não foi possível carregar o login. Verifique a conexão e recarregue.")
    return
  }

  // Already signed in with Clerk but no Phoenix session yet — which is what a
  // reload of this page looks like. Exchange the token instead of showing a
  // form that asks for a login that already happened.
  if (Clerk.user) return exchange(Clerk, sessionPath)

  mount.innerHTML = ""
  installTouchTargets()
  // A altura mínima existe só para a caixa não saltar durante o carregamento.
  mount.style.minHeight = "auto"
  Clerk.mountSignIn(mount, {
    appearance,
    afterSignInUrl: window.location.pathname,
    afterSignUpUrl: window.location.pathname
  })

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
