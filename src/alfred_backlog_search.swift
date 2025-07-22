#!/usr/bin/swift

import Foundation

// MARK: - Data Models
struct Result {
    let projectCode: String
    var url: String
    var title: String
    var subTitle: String
    var updated: String
    
    init(projectCode: String, url: String = "", title: String = "", subTitle: String = "", updated: String = "") {
        self.projectCode = projectCode
        self.url = url
        self.title = title
        self.subTitle = subTitle
        self.updated = updated
    }
}

struct Project {
    let apiKey: String
    let projectId: String
    let workspaceUrl: String
    let projectCode: String
    
    init(apiKey: String, projectId: String, workspaceUrl: String, projectCode: String) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.workspaceUrl = workspaceUrl
        self.projectCode = projectCode
    }
    
    func createResultFromIssue(_ issue: [String: Any]) -> Result? {
        guard let issueKey = issue["issueKey"] as? String else {
            return nil
        }
        
        let updated = issue["updated"] as? String ?? ""
        let link = "\(workspaceUrl)/view/\(issueKey)"
        let summary = issue["summary"] as? String ?? ""
        
        let createdUser = issue["createdUser"] as? [String: Any]
        let owner = createdUser?["name"] as? String ?? "Unknown"
        
        let assignee = issue["assignee"] as? [String: Any]
        let assigneeName = assignee?["name"] as? String ?? "Unknown"
        
        return Result(
            projectCode: projectCode,
            url: link,
            title: summary,
            subTitle: "\(issueKey) \(owner) → \(assigneeName)",
            updated: updated
        )
    }
    
    func search(query: String, isFirst: Bool) -> [Result] {
        // 検索語が指定されていない時、もしくは検索語が数字以外の1文字だった場合
        if query.isEmpty || (!query.isNumeric && query.count == 1) {
            let result = Result(
                projectCode: projectCode,
                url: "\(workspaceUrl)/projects/\(projectCode)",
                title: "プロジェクトホームを開く",
                subTitle: projectCode,
                updated: "Z"
            )
            return [result]
        }
        
        var results: [Result] = []
        
        // 1〜4桁の数字だった場合は課題番号とみなして結果の一番上に入れる
        if query.isNumeric && query.count < 4 {
            let issueKey = "\(projectCode)-\(query)"
            if isFirst {
                let result = Result(
                    projectCode: projectCode,
                    url: "\(workspaceUrl)/view/\(issueKey)",
                    title: "\(issueKey)を開く",
                    subTitle: "",
                    updated: "Z"
                )
                return [result]
            }
            
            // URLComponentsを使って課題詳細APIのURL構築
            guard var components = URLComponents(string: "\(workspaceUrl)/api/v2/issues/\(issueKey)") else {
                let result = Result(
                    projectCode: projectCode,
                    url: "\(workspaceUrl)/view/\(issueKey)",
                    title: "\(issueKey)は見つかりませんでした",
                    subTitle: "",
                    updated: "0"
                )
                results.append(result)
                return results
            }
            
            components.queryItems = [
                URLQueryItem(name: "apiKey", value: apiKey)
            ]
            
            guard let apiUrl = components.url?.absoluteString else {
                let result = Result(
                    projectCode: projectCode,
                    url: "\(workspaceUrl)/view/\(issueKey)",
                    title: "\(issueKey)は見つかりませんでした",
                    subTitle: "",
                    updated: "0"
                )
                results.append(result)
                return results
            }
            
            if let issueData = makeHttpRequest(url: apiUrl),
               let issue = try? JSONSerialization.jsonObject(with: issueData) as? [String: Any],
               let result = createResultFromIssue(issue) {
                let updatedResult = Result(
                    projectCode: result.projectCode,
                    url: result.url,
                    title: result.title,
                    subTitle: result.subTitle,
                    updated: "Z"
                )
                results.append(updatedResult)
            } else {
                let result = Result(
                    projectCode: projectCode,
                    url: "\(workspaceUrl)/view/\(issueKey)",
                    title: "\(issueKey)は見つかりませんでした",
                    subTitle: "",
                    updated: "0"
                )
                results.append(result)
            }
        }
        
        // 3文字以上の場合は課題検索を実行
        if query.count > 2 {
            fputs("query=\(query)\n", stderr)
            
            // URLComponentsを使って検索APIのURL構築
            guard var components = URLComponents(string: "\(workspaceUrl)/api/v2/issues") else {
                fputs("Failed to create URLComponents for search\n", stderr)
                return results
            }
            
            components.queryItems = [
                URLQueryItem(name: "apiKey", value: apiKey),
                URLQueryItem(name: "projectId[]", value: projectId),
                URLQueryItem(name: "count", value: "10"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "order", value: "desc"),
                URLQueryItem(name: "keyword", value: query)
            ]
            
            guard let searchUrl = components.url?.absoluteString else {
                fputs("Failed to generate search URL\n", stderr)
                return results
            }
            
            fputs("Generated URL: \(searchUrl)\n", stderr)
            
            if let searchData = makeHttpRequest(url: searchUrl),
               let issues = try? JSONSerialization.jsonObject(with: searchData) as? [[String: Any]] {
                fputs("Successfully parsed \(issues.count) issues\n", stderr)
                for issue in issues {
                    if let result = createResultFromIssue(issue) {
                        results.append(result)
                    }
                }
            } else {
                fputs("Failed to get or parse search results\n", stderr)
            }
        }
        
        return results
    }
}

struct AlfredItem {
    let uid: String?
    let arg: String
    let title: String
    let subtitle: String
    let icon: String
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "arg": arg,
            "title": title,
            "subtitle": subtitle
        ]
        
        if let uid = uid {
            dict["uid"] = uid
        }
        
        if !icon.isEmpty {
            dict["icon"] = ["path": icon]
        }
        
        return dict
    }
}

struct AlfredOutput {
    var items: [AlfredItem] = []
    var variables: [String: Any] = [:]
    var rerun: Double?
    
    mutating func addItem(uid: String? = nil, arg: String, title: String, subtitle: String = "", icon: String = "") {
        let item = AlfredItem(uid: uid, arg: arg, title: title, subtitle: subtitle, icon: icon)
        items.append(item)
    }
    
    func toJson() -> String {
        var output: [String: Any] = [
            "items": items.map { $0.toDictionary() }
        ]
        
        if !variables.isEmpty {
            output["variables"] = variables
        }
        
        if let rerun = rerun {
            output["rerun"] = rerun
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: output, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{\"items\":[]}"
        }
        
        return jsonString
    }
}

// MARK: - Utility Extensions
extension String {
    var isNumeric: Bool {
        return !isEmpty && allSatisfy { $0.isNumber }
    }
}

// MARK: - Helper Functions
func makeHttpRequest(url: String) -> Data? {
    guard let requestUrl = URL(string: url) else { 
        fputs("Invalid URL: \(url)\n", stderr)
        return nil 
    }
    
    let semaphore = DispatchSemaphore(value: 0)
    var result: Data?
    
    var request = URLRequest(url: requestUrl)
    request.timeoutInterval = 15.0
    
    // HTTPヘッダーを設定
    request.setValue("curl/8.4.0", forHTTPHeaderField: "User-Agent")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 15.0
    config.timeoutIntervalForResource = 30.0
    
    let session = URLSession(configuration: config)
    
    let task = session.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            fputs("URLSession Error: \(error.localizedDescription)\n", stderr)
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            fputs("HTTP Status: \(httpResponse.statusCode)\n", stderr)
            
            if httpResponse.statusCode == 200 {
                result = data
                fputs("Response data length: \(data?.count ?? 0)\n", stderr)
            } else {
                fputs("HTTP Error: Status code \(httpResponse.statusCode)\n", stderr)
            }
        }
    }
    
    task.resume()
    
    // タイムアウト処理
    let timeout = DispatchTime.now() + .seconds(20)
    if semaphore.wait(timeout: timeout) == .timedOut {
        fputs("Request timed out\n", stderr)
        task.cancel()
        return nil
    }
    
    return result
}

func normalizeQuery(_ query: String) -> String {
    // Macで入力した「が」などが「か」と濁点に分かれてしまう問題を解決
    let normalized = query.precomposedStringWithCanonicalMapping
    fputs("Original query: \(query)\n", stderr)
    fputs("Normalized query: \(normalized)\n", stderr)
    return normalized
}

func loadConfig() -> [Project] {
    let configFile = "config.json"
    
    guard let configData = FileManager.default.contents(atPath: configFile),
          let configJson = try? JSONSerialization.jsonObject(with: configData) as? [[String: String]] else {
        return []
    }
    
    return configJson.compactMap { projectData in
        guard let apiKey = projectData["apiKey"],
              let projectId = projectData["projectId"],
              let projectUrl = projectData["projectUrl"],
              let projectCode = projectData["projectCode"] else {
            return nil
        }
        
        return Project(
            apiKey: apiKey,
            projectId: projectId,
            workspaceUrl: projectUrl,
            projectCode: projectCode
        )
    }
}

// MARK: - Main Execution
func main() {
    var alfredOutput = AlfredOutput()
    
    // 初回かどうかを検出
    let isFirst = ProcessInfo.processInfo.environment["isRerun"] == nil
    if isFirst {
        alfredOutput.variables["isRerun"] = true
        alfredOutput.rerun = 0.5 // 0.5秒後に再呼び出し
    }
    
    // プロジェクト設定を読み込み
    let projects = loadConfig()
    
    // クエリを取得（環境変数またはコマンドライン引数から）
    let query = ProcessInfo.processInfo.environment["query"] ?? 
                (CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "")
    
    // 文字正規化
    let normalizedQuery = normalizeQuery(query)
    
    // 各プロジェクトに対して検索実行
    var allResults: [Result] = []
    for project in projects {
        let searchResults = project.search(query: normalizedQuery, isFirst: isFirst)
        allResults.append(contentsOf: searchResults)
    }
    
    if allResults.isEmpty {
        alfredOutput.addItem(
            uid: "0",
            arg: "",
            title: "結果が見つかりません",
            subtitle: ""
        )
    } else {
        // 結果をupdated順でソート
        allResults.sort { first, second in
            if first.updated == "Z" && second.updated != "Z" { return true }
            if first.updated != "Z" && second.updated == "Z" { return false }
            return first.updated > second.updated
        }
        
        // Alfred用の出力を生成
        for result in allResults {
            alfredOutput.addItem(
                arg: result.url,
                title: result.title,
                subtitle: result.subTitle,
                icon: "thumbs/\(result.projectCode).png"
            )
        }
    }
    
    print(alfredOutput.toJson())
}

// 実行
main()