define-command toggle %{
	execute-keys '<a-i>w"ayc'
	execute-keys %sh{
		$kak_config/bin/toggler $kak_opt_filetype $kak_main_reg_a
	}<esc>
}
