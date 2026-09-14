package ai.rever.boss.components.plugin

import ai.rever.boss.plugin.api.PluginContext
import ai.rever.boss.plugin.sandbox.context.SandboxedPluginContext
import kotlin.reflect.KClass
import kotlin.reflect.full.declaredMembers
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Every [PluginContext] member must be declared by both wrappers a dynamic plugin is given.
 *
 * Almost every member has a default implementation that returns null or does nothing, so a member a
 * wrapper does not override compiles, loads and fails silently for every plugin. AGENTS.md records
 * this for `mcpToolRegistry`; `registerSearchProvider` was the same gap in both wrappers.
 *
 * Kotlin reflection, not Java reflection: the api is compiled with the default `-jvm-default=enable`,
 * which puts a compatibility bridge for each default method into every implementing class, so
 * `Class.declaredMethods` lists members a wrapper never overrode. Kotlin metadata lists only what the
 * source declares.
 */
class PluginContextWrapperForwardingTest {
    private fun missingFrom(wrapper: KClass<*>): Set<String> =
        PluginContext::class.declaredMembers.map { it.name }.toSet() -
            wrapper.declaredMembers.map { it.name }.toSet()

    @Test
    fun `TrackingPluginContext declares every PluginContext member`() {
        val missing = missingFrom(TrackingPluginContext::class)
        assertTrue(missing.isEmpty(), "TrackingPluginContext falls through to a PluginContext default for: $missing")
    }

    @Test
    fun `SandboxedPluginContext declares every PluginContext member`() {
        val missing = missingFrom(SandboxedPluginContext::class)
        assertTrue(missing.isEmpty(), "SandboxedPluginContext falls through to a PluginContext default for: $missing")
    }
}
