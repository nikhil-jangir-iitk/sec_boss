package ai.rever.boss.plugin.logging

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A credential embedded in a URL's userinfo (`scheme://user:password@host`) must not survive
 * [LogSanitizer.maskUriParams]. The masker is used at the git-clone, browser-navigation and
 * deep-link log sites, all of which can carry a URL whose authority holds a token: a private
 * HTTPS clone URL is `https://x-access-token:<token>@github.com/...`, and `DesktopGitService`
 * itself branches on `repositoryUrl.contains("@")` for its auth-failure message, so the very
 * URL it logs is expected to carry credentials.
 *
 * Before this, `maskUriParams` masked only sensitive query/fragment parameters and returned the
 * userinfo verbatim.
 */
class UriUserInfoTest {
    @Test
    fun `a password in the authority is redacted`() {
        assertEquals(
            "https://[REDACTED]@github.com/o/r.git",
            LogSanitizer.maskUriParams("https://user:pass@github.com/o/r.git"),
        )
    }

    @Test
    fun `a git access-token clone url is redacted`() {
        assertEquals(
            "https://[REDACTED]@github.com/o/r.git",
            LogSanitizer.maskUriParams("https://x-access-token:ghs_abcdefghijklmnop1234@github.com/o/r.git"),
        )
        assertEquals(
            "https://[REDACTED]@gitlab.com/g/r.git",
            LogSanitizer.maskUriParams("https://oauth2:glpat-abcdefghij1234567890@gitlab.com/g/r.git"),
        )
    }

    @Test
    fun `a bare token as userinfo with no password is redacted`() {
        assertEquals(
            "https://[REDACTED]@github.com/o/r.git",
            LogSanitizer.maskUriParams("https://ghp_abcdefghijklmnopqrstuvwxyz012345@github.com/o/r.git"),
        )
    }

    @Test
    fun `the host port and path are preserved when the userinfo is redacted`() {
        assertEquals(
            "https://[REDACTED]@host.example:8443/a/b?x=1",
            LogSanitizer.maskUriParams("https://user:pass@host.example:8443/a/b?x=1"),
        )
    }

    @Test
    fun `userinfo and a sensitive query parameter are both redacted`() {
        assertEquals(
            "https://[REDACTED]@host.example/cb?token=[REDACTED]&type=signup",
            LogSanitizer.maskUriParams("https://user:pass@host.example/cb?token=secret&type=signup"),
        )
    }

    @Test
    fun `an at sign in the query is not treated as userinfo`() {
        // The @ here is in a query value (an email), not in the authority, so nothing is redacted.
        assertEquals(
            "https://mail.example.com/send?to=alice@example.com",
            LogSanitizer.maskUriParams("https://mail.example.com/send?to=alice@example.com"),
        )
    }

    @Test
    fun `an at sign in the path is not treated as userinfo`() {
        assertEquals(
            "https://example.com/@alice/repo",
            LogSanitizer.maskUriParams("https://example.com/@alice/repo"),
        )
    }

    @Test
    fun `a url with no authority is unchanged`() {
        // No `://`, so there is no authority to hold userinfo; the `@` is ordinary text.
        assertEquals("mailto:alice@example.com", LogSanitizer.maskUriParams("mailto:alice@example.com"))
    }

    @Test
    fun `a plain url without userinfo is unchanged`() {
        assertEquals("https://github.com/o/r.git", LogSanitizer.maskUriParams("https://github.com/o/r.git"))
        assertEquals("boss://auth?type=signup", LogSanitizer.maskUriParams("boss://auth?type=signup"))
    }

    @Test
    fun `a fragment credential is still redacted alongside userinfo`() {
        assertEquals(
            "https://[REDACTED]@app.example/#access_token=[REDACTED]",
            LogSanitizer.maskUriParams("https://user:pass@app.example/#access_token=secret"),
        )
    }
}
