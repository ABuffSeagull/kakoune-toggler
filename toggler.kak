define-command toggle-word %{
	execute-keys '<a-i>w|'
	execute-keys "%val{config}/bin/toggler %opt{filetype}<ret>"
}

define-command toggle-WORD %{
	execute-keys '<a-i><a-w>|'
	execute-keys "%val{config}/bin/toggler %opt{filetype}<ret>"
}
