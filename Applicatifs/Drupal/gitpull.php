<?php

  /* Script to update www from GIT project */
  $pull = shell_exec("/usr/bin/git pull 2>&1");
  echo 'Print Return of git pull command :<br /><br />' . $pull;

?>

