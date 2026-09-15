package ai.rever.boss.plugin.logging

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * [LogSanitizer.describeUri] for a reference with no scheme.
 *
 * `java.net.URI` parses `localhost` or `app?code=x` as a relative reference whose scheme is null, and
 * the description was built by interpolating the scheme, so these read as `null://localhost`. Browser
 * and CLI log lines describe exactly this kind of input: the value a `boss://url` link carries, and the
 * text `CLISecurityValidator.normalizeAndValidateUrl` just rejected.
 */
class DescribeUriReferenceTest {
    private fun assertDescribed(
        expected: String,
        uri: String,
    ) {
        assertEquals(expected, LogSanitizer.describeUri(uri), uri)
    }

    @Test
    fun `a reference with no scheme is described without a null scheme`() {
        assertDescribed("localhost", "localhost")
        assertDescribed("app (with query params)", "app?code=secret")
        assertDescribed("example.com/a/b (with fragment)", "example.com/a/b#token=secret")
    }

    @Test
    fun `a network-path reference keeps its leading slashes`() {
        assertDescribed("//cdn.example.com/f (with query params)", "//cdn.example.com/f?sig=secret")
    }

    @Test
    fun `a query or fragment alone is described without a leading space`() {
        assertDescribed("(with query params)", "?code=secret")
        assertDescribed("(with fragment)", "#access_token=secret")
    }

    @Test
    fun `an absolute URI is described as before`() {
        assertDescribed("https://example.com/cb (with query params)", "https://example.com/cb?code=secret")
        assertDescribed("boss://auth/verify (with query params)", "boss://auth/verify?token=secret")
        assertDescribed("about://", "about:blank")
    }
}
