package ai.rever.boss.utils.logging

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Pins what [LogSanitizer.describeUri] keeps for URLs whose secret sits under a name
 * [LogSanitizer.maskUriParams] does not list.
 *
 * Browser and opened-link log lines use `describeUri` rather than `maskUriParams` because the latter
 * redacts by exact parameter name, and a tab's URL carries credentials under names no list keeps up
 * with. Measured on fourteen credential-bearing URL shapes, `maskUriParams` hid four and `describeUri`
 * twelve; the two it missed carry the token in the path. Those sites now depend on this output dropping
 * the query, the fragment and the userinfo, so it is pinned here rather than assumed.
 *
 * Not covered, by either function: a credential in the path itself (`/reset-password/<token>`, a
 * Slack webhook). `describeUri` also drops the port and reads an opaque URI such as `about:blank`
 * as `about://`, which costs the log a little detail and exposes nothing.
 */
class DescribeUriSecretShapesTest {
    private fun assertDescribed(
        expected: String,
        url: String,
    ) {
        assertEquals(expected, LogSanitizer.describeUri(url), url)
    }

    @Test
    fun `query credentials under names maskUriParams does not list are dropped`() {
        assertDescribed(
            "https://x.firebaseapp.com/__/auth/action (with query params)",
            "https://x.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=SECRET",
        )
        assertDescribed(
            "https://b.s3.amazonaws.com/f.pdf (with query params)",
            "https://b.s3.amazonaws.com/f.pdf?X-Amz-Credential=AKIA&X-Amz-Signature=SECRET",
        )
        assertDescribed(
            "https://a.blob.core.windows.net/c/f (with query params)",
            "https://a.blob.core.windows.net/c/f?sv=2022&sig=SECRET",
        )
        assertDescribed("https://zoom.us/j/123 (with query params)", "https://zoom.us/j/123?pwd=SECRET")
        assertDescribed(
            "https://idp.example.com/token (with query params)",
            "https://idp.example.com/token?client_id=a&client_secret=SECRET",
        )
        assertDescribed("https://api.example.com/v1 (with query params)", "https://api.example.com/v1?apikey=SECRET")
        assertDescribed(
            "https://example.com/passkey (with query params)",
            "https://example.com/passkey?sessionId=SECRET",
        )
    }

    @Test
    fun `fragment credentials and hash-routed queries are dropped`() {
        assertDescribed(
            "https://app.example.com/cb (with fragment)",
            "https://app.example.com/cb#access_token=SECRET&token_type=bearer",
        )
        assertDescribed("https://app.example.com/ (with fragment)", "https://app.example.com/#/reset?token=SECRET")
        assertDescribed(
            "https://example.com/a/b (with query and fragment)",
            "https://example.com:8443/a/b?token=SECRET#state=SECRET",
        )
    }

    @Test
    fun `userinfo is dropped`() {
        assertDescribed("https://github.com/o/r.git", "https://x-access-token:SECRET@github.com/o/r.git")
    }

    @Test
    fun `input java-net-URI rejects gives a placeholder rather than the text`() {
        // CLICommandHandler logs exactly the input that failed validation, which is often not a URI.
        assertDescribed("[uri-parse-error]", "https://exa mple.com/?token=SECRET")
        assertDescribed("[uri-parse-error]", "https://x.example/?q=%zz&token=SECRET")
    }
}
