define-command toggle-word %{
	execute-keys '<a-i>w"ayc'
	execute-keys %sh{
		$kak_config/bin/toggler $kak_main_reg_a $kak_opt_filetype
	}<esc>
}

define-command toggle-WORD %{
	execute-keys '<a-i><a-w>"ayc'
	execute-keys %sh{
		$kak_config/bin/toggler $kak_main_reg_a $kak_opt_filetype
	}<esc>
}
