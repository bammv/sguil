#==============================================================================
# Creates some images.
#
# Copyright (c) 2011-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Create two images, to be displayed in tablelist cells with boolean values
#
image create photo checkedImg   -file [file join $dir checked.gif]
image create photo uncheckedImg -file [file join $dir unchecked.gif]

#
# Create 16 images representing different colors
#
set colorNames {
    "red" "green" "blue" "magenta"
    "yellow" "cyan" "white" "light gray"
    "dark red" "dark green" "dark blue" "dark magenta"
    "dark yellow" "dark cyan" "dark gray" "black"
}
set colorValues {
    #FF0000 #00FF00 #0000FF #FF00FF
    #FFFF00 #00FFFF #FFFFFF #C0C0C0
    #800000 #008000 #000080 #800080
    #808000 #008080 #808080 #000000
}
foreach name $colorNames value $colorValues {
    set colors($name) $value
}
foreach value $colorValues {
    image create photo img$value -height 13 -width 13
    img$value put gray50 -to 0 0 13 1				;# top edge
    img$value put gray50 -to 0 1 1 12				;# left edge
    img$value put gray75 -to 0 12 13 13				;# bottom edge
    img$value put gray75 -to 12 1 13 12				;# right edge
    img$value put $value -to 1 1 12 12
}
