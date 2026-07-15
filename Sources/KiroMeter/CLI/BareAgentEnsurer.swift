import Foundation

/// Ensures the `bare` agent config exists at ~/.kiro/agents/bare.json.
/// This agent is required for the optimized CLI call with `--agent bare`.
/// Without it, kiro-cli will fail when using the bare agent flag.
public enum BareAgentEnsurer {

    private static let agentConfig = """
    {
      "name": "bare",
      "description": "Minimal agent with no MCP servers for fast queries",
      "tools": [],
      "mcpServers": {}
    }
    """

    /// Ensure bare.json exists. Creates it if missing.
    /// Returns true if the file exists (either already existed or was created).
    @discardableResult
    public static func ensureExists() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let agentsDir = home.appendingPathComponent(".kiro/agents")
        let bareFile = agentsDir.appendingPathComponent("bare.json")

        // Already exists
        if FileManager.default.fileExists(atPath: bareFile.path) {
            return true
        }

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(
                at: agentsDir,
                withIntermediateDirectories: true
            )
        } catch {
            print("BareAgentEnsurer: failed to create agents directory: \(error)")
            return false
        }

        // Write config
        do {
            try agentConfig.write(to: bareFile, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("BareAgentEnsurer: failed to write bare.json: \(error)")
            return false
        }
    }
}
