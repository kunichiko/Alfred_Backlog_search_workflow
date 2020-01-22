require_once('workflows.php');

class Result { 
	public $projectCode;
	public $url;
	public $title;
	public $updated;
	function __construct($projectCode_, $url_, $title_, $updated_) {
		$this->projectCode = $projectCode_;
		$this->url = $url_;
		$this->title = $title_;
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

	public function search(string $query) {
		if ( strlen($query) == 0 || (!is_numeric($query) && strlen($query) == 1) ) {
			$result = new Result($this->projectCode, $this->workspaceUrl."/projects/".$this->projectCode, $this->projectCode." プロジェクトホームを開く", "");
			return array($result);
		}

		$wf = new Workflows();
		$results = array();

		if ( is_numeric($query) && strlen($query) < 4 ) {
			$results[] = new Result($this->projectCode, $this->workspaceUrl."/view/".$this->projectCode."-".$query, $this->projectCode."-".$query."を開く", "Z");
		}

		$json = $wf->request( $this->workspaceUrl."/api/v2/issues?apiKey=".$this->apiKey."&projectId[]=".$this->projectId."&count=10&sort=updated&order=desc&keyword=".urlencode($query) );

		$array = json_decode( $json , true );

		for($i=0; $i < 9; $i++) {
		    $issueKey = $array[$i]["issueKey"]; // HOGE-123 など
			if ( $issueKey == null ) {
				break;
			}
			$updated = $array[$i]["updated"];
		    $link = $this->workspaceUrl."/view/".$issueKey;
		    $summary = $array[$i]["summary"]; // タイトル
			$results[] = new Result($this->projectCode, $link, $issueKey." ".$summary, $updated);
		}
		return $results;
	}
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
$orig = trim(shell_exec('echo "{query}" | /usr/local/bin/nkf -wLu --ic=UTF8-MAC'));

// 各プロジェクトに対して検索実行
$results = array();
foreach ( $projects as $project ) {
	$searchResults = $project->search($orig);
	$results = array_merge($results, $searchResults);
}

$wf = new Workflows();
if ( count($results) == 0 ) {
	$wf->result(
		0,
		"",
     	"結果が見つかりません",
		'',
		$icon
 	);

} else {
	foreach ( $results as $key => $value) {
        $sort_keys[$key] = $value->updated;
	}
	array_multisort($sort_keys, SORT_DESC, $results);

	$i=0;
	foreach ( $results as $result) {
		$wf->result(
			$i++,
			$result->url,
			$result->title,
			'',
			"thumbs/".$result->projectCode.".png"
		);
	}
}

echo $wf->toxml();
