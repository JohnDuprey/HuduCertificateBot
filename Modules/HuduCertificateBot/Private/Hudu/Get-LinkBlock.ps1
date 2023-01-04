function Get-LinkBlock($URL, $Icon, $Title) {
    return "<div class='o365__app' style='text-align:center'><a href=$URL target=_blank><i class=`"$Icon`">&nbsp;&nbsp;&nbsp;</i>$Title</a></div>"
}