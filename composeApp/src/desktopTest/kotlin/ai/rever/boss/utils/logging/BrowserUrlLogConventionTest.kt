package ai.rever.boss.utils.logging

import ai.rever.boss.testsupport.repoRoot
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail

/**
 * Asserts that the files carrying a browser or opened-link URL into a log line never put the URL into
 * the data map unsanitized.
 *
 * `BossLogger` appends the data map to the line as-is, the line goes to `System.out`, and
 * `GlobalLogCapture` keeps it for the Console panel - which every plugin reads through
 * `PluginContext.logDataProvider`, and which the console plugin serves to MCP clients through
 * `console_tail` and `console_search`. A tab's URL is where an OAuth `code`, a magic-link `token` or a
 * presigned `X-Amz-Signature` lives, and "Browser created via BrowserService" logged it at INFO, the
 * default level, on every tab creation, hibernation wake and crash recovery.
 *
 * A convention test rather than review vigilance because the leak is one missing call in an argument
 * list, and every one of these files already sanitizes some of its URLs, so a raw one reads as
 * correct next to them.
 *
 * **Scoped to named files, not the whole tree.** Other open work owns the remaining raw sites
 * (authentication logging, and `URLHandlerService`, whose URL routing is being rewritten), and a
 * tree-wide scan would have to allowlist lines another change is about to move. Add a file here once
 * its URL logging is sanitized.
 *
 * Still a text check: it parses each `logger.<level>(...)` call and looks at `"key" to value` pairs
 * whose key ends in url, uri, link or href. A URL logged under some other key, or built into the
 * message string, is not seen - neither shape occurs in this repo's host sources today.
 */
class BrowserUrlLogConventionTest {
    private val guarded =
        listOf(
            "composeApp/src/desktopMain/kotlin/ai/rever/boss/plugin/browser/BrowserServiceImpl.kt",
            "composeApp/src/desktopMain/kotlin/ai/rever/boss/utils/DeepLinkHandler.kt",
            "composeApp/src/desktopMain/kotlin/ai/rever/boss/cli/CLICommandHandler.kt",
        )

    @Test
    fun `guarded files log no url-keyed value without LogSanitizer`() {
        val root = repoRoot()
        val offenders =
            guarded.flatMap { path ->
                val file = File(root, path)
                check(file.isFile) { "guarded file moved or renamed: $path" }
                unsanitizedUrlEntries(file.readText()).map { "$path:${it.line}  ${it.entry}" }
            }

        if (offenders.isNotEmpty()) {
            fail(
                "These log calls put a URL into the data map as-is, so any token in its query or " +
                    "fragment reaches the Console capture that plugins and MCP clients read. Wrap it in " +
                    "LogSanitizer.describeUri (or maskUriParams where the query is needed):\n  " +
                    offenders.joinToString("\n  "),
            )
        }
    }

    @Test
    fun `the scan finds single-line, multi-line and suffixed keys, and ignores sanitized ones`() {
        val source =
            """
            fun f() {
                logger.info(LogCategory.BROWSER, "a", mapOf("url" to url))
                logger.warn(
                    LogCategory.BROWSER,
                    "b (not a closing paren",
                    mapOf(
                        "handleId" to id,
                        "targetUrl" to config.url,
                    ),
                )
                logger.debug(LogCategory.SYSTEM, "c", mapOf("uri" to uri, "n" to 1))
                logger.info(LogCategory.BROWSER, "d", mapOf("url" to LogSanitizer.describeUri(url)))
                logger.info(LogCategory.BROWSER, "e", mapOf("url" to LogSanitizer.maskUriParams(url)))
                logger.info(LogCategory.BROWSER, "f", mapOf("hasUrl" to (url != null)))
                val notALog = mapOf("url" to url)
            }
            """.trimIndent()

        assertEquals(
            listOf(2 to "\"url\" to url", 8 to "\"targetUrl\" to config.url", 11 to "\"uri\" to uri"),
            unsanitizedUrlEntries(source).map { it.line to it.entry },
        )
    }

    private data class Entry(
        val line: Int,
        val entry: String,
    )

    private val loggerCall = Regex("""\blogger\.(trace|debug|info|warn|error)\s*\(""")
    private val urlKeyed = Regex(""""([A-Za-z_]*(?:[Uu]rl|[Uu]ri|URL|URI|[Ll]ink|[Hh]ref))"\s+to\s+""")

    /** `hasUrl`, `isLink`: a flag about a URL, not the URL. */
    private val booleanKey = Regex("""^(has|is)[A-Z]""")

    private fun unsanitizedUrlEntries(source: String): List<Entry> =
        loggerCall
            .findAll(source)
            .flatMap { call ->
                val open = call.range.last
                val args = source.substring(open, closingParen(source, open) + 1)
                urlKeyed.findAll(args).mapNotNull { pair ->
                    val value = valueExpression(args, pair.range.last + 1)
                    if (value.startsWith("LogSanitizer.") || booleanKey.containsMatchIn(pair.groupValues[1])) {
                        null
                    } else {
                        val line = source.substring(0, open + pair.range.first).count { it == '\n' } + 1
                        Entry(line, "\"${pair.groupValues[1]}\" to $value")
                    }
                }
            }.toList()

    /** Index of the parenthesis closing the one at [open], skipping string literals. */
    private fun closingParen(
        source: String,
        open: Int,
    ): Int {
        var depth = 0
        var inString = false
        var i = open
        while (i < source.length) {
            val c = source[i]
            when {
                inString && c == '\\' -> i++
                c == '"' -> inString = !inString
                !inString && c == '(' -> depth++
                !inString && c == ')' -> if (--depth == 0) return i
            }
            i++
        }
        error("unbalanced call starting at offset $open")
    }

    /** The value of a `key to value` pair: up to the next top-level comma or closing bracket. */
    private fun valueExpression(
        args: String,
        start: Int,
    ): String {
        var depth = 0
        for (i in start until args.length) {
            val c = args[i]
            if (depth == 0 && (c == ',' || c in ")]}")) return args.substring(start, i).trim()
            if (c in "([{") {
                depth++
            } else if (c in ")]}") {
                depth--
            }
        }
        return args.substring(start).trim()
    }
}
