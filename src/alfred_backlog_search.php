require_once('workflows.php');

class Result { 
	public $projectCode;
	public $url;
	public $title;
	public $subTitle;
	public $updated;
	function __construct($projectCode_, $url_, $title_, $subTitle_, $updated_) {
		$this->projectCode = $projectCode_;
		$this->url = $url_;
		$this->title = $title_;
		$this->subTitle = $subTitle_;
		$this->updated = $updated_;
	}
}

class Project {
	public $apikey;
	public $projectId;
	public $workspaceUrl;
	public $projectCode;

	function __construct($apiKey_, $projectId_, $workspaceUrl_, $projectCode_) {
		$this->apiKey = $apiKey_;
		$this->projectId = $projectId_;
		$this->workspaceUrl = $workspaceUrl_;
		$this->projectCode = $projectCode_;
	}

	function setIssueToResult($issue, $result) {
        if ( $issue == null) {
            return false;
        }
		$issueKey = $issue["issueKey"]; // HOGE-123 など
		if ( $issueKey == null ) {
			return false;
		}
		$updated = $issue["updated"];
		$link = $this->workspaceUrl."/view/".$issueKey;
		$summary = $issue["summary"]; // タイトル
		$owner = ($issue["createdUser"] ?? array('name'=>'Unknown'))["name"]; // 登録者名
		$assignee = ($issue["assignee"] ?? array('name'=>'Unknown'))["name"]; // 担当者名
		// 
		$result->url = $link;
		$result->title = $summary;
		$result->subTitle = $issueKey." ".$owner." → ".$assignee;
		$result->updated = $updated;
		return true;
	 }

	public function search(string $query, bool $isFirst) {
		// 検索語が指定されていない時、もしくは検索語が数字以外の1文字だった場合
		// この場合、Backlog課題検索APIは1文字の検索ができないので「プロジェクトホームを開く」を返す
		// (数字一文字の場合は課題番号として有効なので次へ)
		if ( is_null($query) || strlen($query) == 0 || (!is_numeric($query) && strlen($query) == 1) ) {
			$result = new Result($this->projectCode, $this->workspaceUrl."/projects/".$this->projectCode, "プロジェクトホームを開く", $this->projectCode, "Z");
			return array($result);
		}

		$wf = new Workflows();
		$results = array();

		// 1〜4桁の数字だった場合は課題番号とみなして結果の一番上に入れる(ソートキーを'Z'に設定)
		if ( is_numeric($query) && strlen($query) < 4 ) {
			$issueKey = $this->projectCode."-".$query;
			if ( $isFirst ) {
				$results[] = new Result($this->projectCode, $this->workspaceUrl."/view/".$issueKey, $issueKey."を開く", "", "Z");
				return $results;
			}
            //error_log("REQUEST 1\n");
			$json = $wf->request( $this->workspaceUrl."/api/v2/issues/".$issueKey."?apiKey=".$this->apiKey );
            //error_log($json);
			$issue = json_decode ( $json, true);
            //error_log(json_encode($issue));
			$result = new Result($this->projectCode, "", "", "", "");
			if ( $this->setIssueToResult($issue, $result) ) {
				$result->updated = "Z";
			} else {
				$result = new Result($this->projectCode, $this->workspaceUrl."/view/".$issueKey, $issueKey."は見つかりませんでした", "", "Z");
			}
			$results[] = $result;
		}

		if ( strlen($query) > 2 ) {
            //error_log("REQUEST 2\n");
        	$json = $wf->request( $this->workspaceUrl."/api/v2/issues?apiKey=".$this->apiKey."&projectId[]=".$this->projectId."&count=10&sort=updated&order=desc&keyword=".urlencode($query) );
            //error_log($json);
    		$array = json_decode( $json , true );

            for($i=0; $i < count($array); $i++) {
                $issue = $array[$i];
                $result = new Result($this->projectCode, "", "", "", "");
                if ( $this->setIssueToResult($issue, $result) ) {
                    $results[] = $result;
                }
            }
        }
		return $results;
	}
}

$wf = new Workflows();

// 初回かどうかを検出
$isFirst = getenv('isRerun') == null;
if ( $isFirst ) {
	$wf->variables['isRerun'] = true;
	$wf->rerun = 0.5; // 0.5秒後に再呼び出しさせる
}

// Backlogプロジェクト設定ファイルを読み込み
$configFile = "config.json";
$configJson = file_get_contents($configFile);
$configProjects = json_decode( $configJson, true);
$projects = array();
foreach ( $configProjects as $p ) {
	$project = new Project($p["apiKey"], $p["projectId"], $p["projectUrl"], $p["projectCode"]);
	array_push($projects, $project);
}

// Macで入力した「が」などが「か」と濁点に分かれてしまいBacklogの検索に失敗するため、
// nkfを使って入力文字を Unicode の NFDから NFCに変換する。
$orig = trim(shell_exec('echo "{query}" | PATH=$PATH:/usr/local/bin:/opt/homebrew/bin nkf -wLu --ic=UTF8-MAC'));

// 各プロジェクトに対して検索実行
$results = array();
foreach ( $projects as $project ) {
	$searchResults = $project->search($orig, $isFirst);
	$results = array_merge($results, $searchResults);
}

if ( count($results) == 0 ) {
	$wf->result(
		0,
		"",
     	"結果が見つかりません",
		'',
		''
 	);

} else {
	$sort_keys = array();
	foreach ( $results as $key => $value) {
        $sort_keys[$key] = $value->updated;
	}
	array_multisort($sort_keys, SORT_DESC, $results);

	$i=0;
	foreach ( $results as $result) {
		$wf->result(
			null, // Alfredが認識するユニークID。nullにしておくとこちらが決めた順番のまま表示される。
			$result->url, // arg (次のフローに渡る値)
			$result->title,
			($result->subTitle),
			"thumbs/".$result->projectCode.".png"
		);
	}
}

//error_log($wf->tojson());
echo $wf->tojson();
