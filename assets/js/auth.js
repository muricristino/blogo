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
    colorBackground: "#ffffff",
    borderRadius: "11px",
    fontFamily: "'IBM Plex Sans', ui-sans-serif, system-ui, sans-serif"
  },
  elements: { footer: { display: "none" } }
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
    await Clerk.load({ appearance })
  } catch (error) {
    fail("Não foi possível carregar o login. Verifique a conexão e recarregue.")
    return
  }

  // Already signed in with Clerk but no Phoenix session yet — which is what a
  // reload of this page looks like. Exchange the token instead of showing a
  // form that asks for a login that already happened.
  if (Clerk.user) return exchange(Clerk, sessionPath)

  mount.innerHTML = ""
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
