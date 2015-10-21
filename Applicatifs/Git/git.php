<html>
<head>
	<!-- Latest compiled and minified CSS -->
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">

	<!-- Optional theme -->
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css">

	<!-- Latest compiled and minified JavaScript -->
	<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>

	<meta name="viewport" content="width=device-width, initial-scale=1">
</head>

<body style="width: 90%; margin: auto; margin-top: 20px;">


<div class="container-fluid">
<div class="row">

	<?php

	if (isset($_GET['action']) && $_GET['action'] == 'pull') {
		$pull = shell_exec("/usr/bin/git pull 2>&1");

		echo '<pre>Print Return of git pull command :<br /><br />' . $pull . '</pre>';
	}
	elseif (isset($_GET['action']) && $_GET['action'] == 'status') {
		$status = shell_exec("/usr/bin/git status 2>&1");

		echo '<pre>Print Return of git status command :<br /><br />' . $status . '</pre>';
	}
	elseif (isset($_GET['action']) && $_GET['action'] == 'push' && isset($_POST['message'])) {
		$result1 = trim(shell_exec('/usr/bin/git commit -a -m "' . str_replace('"', "'", $_POST['message']) . '" 2>&1'), " \t");
		$result2 = trim(shell_exec('/usr/bin/git push 2>&1'));
		echo '<pre>
		Print Return of git commit command :<br />' . $result1 . '<br /><br />
		Print Return of git push command :<br />' . $result2 . '
		</pre>';
	}
	?>

	<h3>Faire un GIT status</h3>
	<a class="btn btn-primary" href="?action=status">Git Status</a>

	<hr />

	<h3>Faire un GIT pull</h3>
	<a class="btn btn-primary" href="?action=pull">Git Pull</a>

	<hr />

	<h3>Faire un GIT push</h3>
	<form class="form-horizontal" action="?action=push" method="post" style="margin-top: 35px;">
	 	<div class="form-group">
			<label for="message" class="col-sm-2 control-label">Message de commit</label>
			<div class="col-sm-5">
				<input type="text" class="form-control" name="message" id="message" />
			</div>
		</div>

		<div class="form-group">
    		<div class="col-sm-offset-2 col-sm-10">
				<button type="submit" class="btn btn-primary">Git Push</button>
			</div>
		</div>	
	</form>

</div>
</div>
</body>
</html>