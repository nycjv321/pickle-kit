import Foundation

/// Generates a self-contained HTML report from test run results.
public struct HTMLReportGenerator: Sendable {

    public init() {}

    /// Generate a complete HTML string from the test run result.
    public func generate(from result: TestRunResult) -> String {
        var html = ""
        html += "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
        html += "<meta charset=\"UTF-8\">\n"
        html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
        html += "<title>PickleKit Test Report</title>\n"
        html += generateCSS()
        html += "</head>\n<body>\n"
        html += generateHeader(from: result)
        html += generateSummary(from: result)
        html += "<div class=\"controls\">\n"
        html += "  <button onclick=\"expandAll()\">Expand All</button>\n"
        html += "  <button onclick=\"collapseAll()\">Collapse All</button>\n"
        html +=
            "  <button onclick=\"filterStatus('all')\" class=\"active\" data-filter=\"all\">All</button>\n"
        html +=
            "  <button onclick=\"filterStatus('passed')\" data-filter=\"passed\">Passed</button>\n"
        html +=
            "  <button onclick=\"filterStatus('skipped')\" data-filter=\"skipped\">Skipped</button>\n"
        html +=
            "  <button onclick=\"filterStatus('failed')\" data-filter=\"failed\">Failed</button>\n"
        html += "</div>\n"
        html += generateFeatures(from: result)
        html += generateJS()
        html += "</body>\n</html>"
        return html
    }

    /// Write the report HTML to a file path, creating intermediate directories if needed.
    public func write(result: TestRunResult, to path: String) throws {
        let html = generate(from: result)
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try html.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Generators

    private func generateCSS() -> String {
        return """
            <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 20px; }
            .report-header { background: #2c3e50; color: white; padding: 24px; border-radius: 8px; margin-bottom: 20px; }
            .report-header h1 { font-size: 24px; margin-bottom: 8px; }
            .report-header .timestamp { opacity: 0.8; font-size: 14px; }
            .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 20px; }
            .summary-card { background: white; border-radius: 8px; padding: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.12); }
            .summary-card h3 { font-size: 13px; text-transform: uppercase; color: #666; margin-bottom: 8px; }
            .summary-card .count { font-size: 28px; font-weight: bold; }
            .summary-card .breakdown { font-size: 13px; color: #888; margin-top: 4px; }
            .progress-bar { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; margin-top: 8px; display: flex; }
            .progress-bar .passed { background: #27ae60; }
            .progress-bar .failed { background: #e74c3c; }
            .progress-bar .skipped { background: #95a5a6; }
            .progress-bar .undefined { background: #f39c12; }
            .controls { margin-bottom: 20px; display: flex; gap: 8px; flex-wrap: wrap; }
            .controls button { padding: 8px 16px; border: 1px solid #ddd; background: white; border-radius: 4px; cursor: pointer; font-size: 13px; }
            .controls button:hover { background: #f0f0f0; }
            .controls button.active { background: #2c3e50; color: white; border-color: #2c3e50; }
            .feature { background: white; border-radius: 8px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.12); overflow: hidden; }
            .feature-header { padding: 16px; border-bottom: 1px solid #eee; display: flex; align-items: center; justify-content: space-between; }
            .feature-header h2 { font-size: 18px; }
            .feature-header .feature-stats { font-size: 13px; color: #888; }
            .tag { display: inline-block; background: #e8f4fd; color: #2980b9; padding: 2px 8px; border-radius: 10px; font-size: 11px; margin-right: 4px; }
            .scenario { border-bottom: 1px solid #f0f0f0; }
            .scenario:last-child { border-bottom: none; }
            .scenario summary { padding: 12px 16px; cursor: pointer; display: flex; align-items: center; gap: 8px; list-style: none; }
            .scenario[data-status="failed"] summary { background: #fdf2f2; }
            .scenario summary::-webkit-details-marker { display: none; }
            .scenario summary::before { content: '\\25B6'; font-size: 10px; transition: transform 0.2s; color: #999; }
            .scenario[open] summary::before { transform: rotate(90deg); }
            .scenario-name { font-weight: 500; }
            .scenario-duration { font-size: 12px; color: #999; margin-left: auto; }
            .status-badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; text-transform: uppercase; }
            .status-passed { background: #d4efdf; color: #27ae60; }
            .status-failed { background: #fadbd8; color: #e74c3c; }
            .status-skipped { background: #eaecee; color: #95a5a6; }
            .status-undefined { background: #fdebd0; color: #f39c12; }
            .steps { padding: 0 16px 12px 16px; }
            .step-row { display: flex; align-items: baseline; padding: 4px 0; font-size: 13px; font-family: 'SF Mono', Menlo, monospace; }
            .step-keyword { color: #8e44ad; font-weight: 600; min-width: 60px; }
            .step-text { flex: 1; }
            .step-duration { color: #999; font-size: 11px; min-width: 70px; text-align: right; }
            .step-row.passed .step-text { color: #333; }
            .step-row.failed .step-text { color: #e74c3c; }
            .step-row.skipped .step-text { color: #95a5a6; }
            .step-row.undefined .step-text { color: #f39c12; }
            .step-error { background: #fdf2f2; border-left: 3px solid #e74c3c; padding: 8px 12px; margin: 4px 0 4px 60px; font-size: 12px; color: #c0392b; font-family: 'SF Mono', Menlo, monospace; white-space: pre-wrap; word-break: break-word; }
            .duration { font-size: 14px; color: #888; }
            .hidden { display: none !important; }
            </style>

            """
    }

    private func generateHeader(from result: TestRunResult) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let duration = formatDuration(result.duration)

        var html = "<div class=\"report-header\">\n"
        html += "  <h1>PickleKit Test Report</h1>\n"
        html +=
            "  <div class=\"timestamp\">\(esc(formatter.string(from: result.startTime))) &mdash; Duration: \(duration)</div>\n"
        html += "</div>\n"
        return html
    }

    private func generateSummary(from result: TestRunResult) -> String {
        var html = "<div class=\"summary\">\n"

        // Features card
        html += "  <div class=\"summary-card\">\n"
        html += "    <h3>Features</h3>\n"
        html += "    <div class=\"count\">\(result.totalFeatureCount)</div>\n"
        html +=
            "    <div class=\"breakdown\">\(result.passedFeatureCount) passed, \(result.failedFeatureCount) failed</div>\n"
        html += progressBar(
            passed: result.passedFeatureCount, failed: result.failedFeatureCount, skipped: 0,
            undefined: 0, total: result.totalFeatureCount)
        html += "  </div>\n"

        // Scenarios card
        html += "  <div class=\"summary-card\">\n"
        html += "    <h3>Scenarios</h3>\n"
        html += "    <div class=\"count\">\(result.totalScenarioCount)</div>\n"
        html +=
            "    <div class=\"breakdown\">\(result.passedScenarioCount) passed, \(result.failedScenarioCount) failed"
        if result.skippedScenarioCount > 0 {
            html += ", \(result.skippedScenarioCount) skipped"
        }
        html += "</div>\n"
        html += progressBar(
            passed: result.passedScenarioCount, failed: result.failedScenarioCount,
            skipped: result.skippedScenarioCount, undefined: 0, total: result.totalScenarioCount)
        html += "  </div>\n"

        // Steps card
        html += "  <div class=\"summary-card\">\n"
        html += "    <h3>Steps</h3>\n"
        html += "    <div class=\"count\">\(result.totalStepCount)</div>\n"
        html +=
            "    <div class=\"breakdown\">\(result.passedStepCount) passed, \(result.failedStepCount) failed, \(result.skippedStepCount) skipped"
        if result.undefinedStepCount > 0 {
            html += ", \(result.undefinedStepCount) undefined"
        }
        html += "</div>\n"
        html += progressBar(
            passed: result.passedStepCount, failed: result.failedStepCount,
            skipped: result.skippedStepCount, undefined: result.undefinedStepCount,
            total: result.totalStepCount)
        html += "  </div>\n"

        html += "</div>\n"
        return html
    }

    private func generateFeatures(from result: TestRunResult) -> String {
        var html = ""
        for feature in result.featureResults {
            let featureStatus: String
            if feature.failedCount > 0 {
                featureStatus = "failed"
            } else if feature.scenarioResults.allSatisfy(\.skipped) {
                featureStatus = "skipped"
            } else {
                featureStatus = "passed"
            }
            html += "<div class=\"feature\" data-status=\"\(featureStatus)\">\n"
            html += "  <div class=\"feature-header\">\n"
            html += "    <div>\n"
            html += "      <h2>\(esc(feature.featureName))</h2>\n"
            if !feature.tags.isEmpty {
                html += "      <div style=\"margin-top: 4px;\">"
                for tag in feature.tags {
                    html += "<span class=\"tag\">@\(esc(tag))</span>"
                }
                html += "</div>\n"
            }
            html += "    </div>\n"
            html += "    <div class=\"feature-stats\">"
            let executedCount = feature.scenarioResults.count - feature.skippedCount
            html += "\(feature.passedCount)/\(executedCount) scenarios passed"
            if feature.skippedCount > 0 {
                html += ", \(feature.skippedCount) skipped"
            }
            html += " &middot; \(formatDuration(feature.duration))"
            html += "</div>\n"
            html += "  </div>\n"

            for scenario in feature.scenarioResults {
                let statusClass =
                    scenario.skipped ? "skipped" : (scenario.passed ? "passed" : "failed")
                let openAttr = (!scenario.passed && !scenario.skipped) ? " open" : ""
                html += "  <details class=\"scenario\" data-status=\"\(statusClass)\"\(openAttr)>\n"
                html += "    <summary>\n"
                html += "      <span class=\"scenario-name\">\(esc(scenario.scenarioName))</span>\n"
                html +=
                    "      <span class=\"status-badge status-\(statusClass)\">\(statusClass)</span>\n"
                if !scenario.tags.isEmpty {
                    for tag in scenario.tags {
                        html += "      <span class=\"tag\">@\(esc(tag))</span>\n"
                    }
                }
                html +=
                    "      <span class=\"scenario-duration\">\(formatDuration(scenario.duration))</span>\n"
                html += "    </summary>\n"
                html += "    <div class=\"steps\">\n"

                for stepResult in scenario.stepResults {
                    let stepClass = stepResult.status.rawValue
                    html += "      <div class=\"step-row \(stepClass)\">\n"
                    html +=
                        "        <span class=\"step-keyword\">\(esc(stepResult.keyword))</span>\n"
                    html += "        <span class=\"step-text\">\(esc(stepResult.text))</span>\n"
                    if stepResult.duration > 0 {
                        html +=
                            "        <span class=\"step-duration\">\(formatDuration(stepResult.duration))</span>\n"
                    }
                    html += "      </div>\n"
                    if let error = stepResult.error {
                        html += "      <div class=\"step-error\">\(esc(error))</div>\n"
                    }
                }

                html += "    </div>\n"
                html += "  </details>\n"
            }

            html += "</div>\n"
        }
        return html
    }

    private func generateJS() -> String {
        return """
            <script>
            function expandAll() {
              document.querySelectorAll('details.scenario:not(.hidden)').forEach(d => d.open = true);
            }
            function collapseAll() {
              document.querySelectorAll('details.scenario').forEach(d => d.open = false);
            }
            function filterStatus(status) {
              document.querySelectorAll('.controls button[data-filter]').forEach(b => b.classList.remove('active'));
              document.querySelector('.controls button[data-filter="' + status + '"]').classList.add('active');

              document.querySelectorAll('.feature').forEach(feature => {
                const scenarios = feature.querySelectorAll('.scenario');
                let anyVisible = false;
                scenarios.forEach(s => {
                  if (status === 'all' || s.dataset.status === status) {
                    s.classList.remove('hidden');
                    anyVisible = true;
                  } else {
                    s.classList.add('hidden');
                  }
                });
                feature.classList.toggle('hidden', !anyVisible);
              });
            }
            </script>

            """
    }

    // MARK: - Helpers

    private func esc(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.0f\u{00B5}s", seconds * 1_000_000)
        } else if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.2fs", seconds)
        } else {
            let mins = Int(seconds) / 60
            let secs = seconds - Double(mins * 60)
            return String(format: "%dm %.1fs", mins, secs)
        }
    }

    private func progressBar(passed: Int, failed: Int, skipped: Int, undefined: Int, total: Int)
        -> String
    {
        guard total > 0 else { return "" }
        let pPct = Double(passed) / Double(total) * 100
        let fPct = Double(failed) / Double(total) * 100
        let sPct = Double(skipped) / Double(total) * 100
        let uPct = Double(undefined) / Double(total) * 100

        var html = "    <div class=\"progress-bar\">"
        if passed > 0 { html += "<div class=\"passed\" style=\"width:\(pPct)%\"></div>" }
        if failed > 0 { html += "<div class=\"failed\" style=\"width:\(fPct)%\"></div>" }
        if skipped > 0 { html += "<div class=\"skipped\" style=\"width:\(sPct)%\"></div>" }
        if undefined > 0 { html += "<div class=\"undefined\" style=\"width:\(uPct)%\"></div>" }
        html += "</div>\n"
        return html
    }
}
