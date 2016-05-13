#==============================================================================
# Contains procedures that create various bitmap and photo images.  The
# argument w specifies a canvas displaying a sort arrow, while the argument win
# stands for a tablelist widget.
#
# Copyright (c) 2006-2015  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#------------------------------------------------------------------------------
# tablelist::flat5x3Arrows
#------------------------------------------------------------------------------
proc tablelist::flat5x3Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp5x3_width 5
#define triangleUp5x3_height 3
static unsigned char triangleUp5x3_bits[] = {
   0x04, 0x0e, 0x1f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn5x3_width 5
#define triangleDn5x3_height 3
static unsigned char triangleDn5x3_bits[] = {
   0x1f, 0x0e, 0x04};
"
}

#------------------------------------------------------------------------------
# tablelist::flat5x4Arrows
#------------------------------------------------------------------------------
proc tablelist::flat5x4Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp5x4_width 5
#define triangleUp5x4_height 4
static unsigned char triangleUp5x4_bits[] = {
   0x04, 0x0e, 0x1f, 0x1f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn5x4_width 5
#define triangleDn5x4_height 4
static unsigned char triangleDn5x4_bits[] = {
   0x1f, 0x1f, 0x0e, 0x04};
"
}

#------------------------------------------------------------------------------
# tablelist::flat6x4Arrows
#------------------------------------------------------------------------------
proc tablelist::flat6x4Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp6x4_width 6
#define triangleUp6x4_height 4
static unsigned char triangleUp6x4_bits[] = {
   0x0c, 0x1e, 0x3f, 0x3f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn6x4_width 6
#define triangleDn6x4_height 4
static unsigned char triangleDn7x4_bits[] = {
   0x3f, 0x3f, 0x1e, 0x0c};
"
}

#------------------------------------------------------------------------------
# tablelist::flat7x4Arrows
#------------------------------------------------------------------------------
proc tablelist::flat7x4Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp7x4_width 7
#define triangleUp7x4_height 4
static unsigned char triangleUp7x4_bits[] = {
   0x08, 0x1c, 0x3e, 0x7f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn7x4_width 7
#define triangleDn7x4_height 4
static unsigned char triangleDn7x4_bits[] = {
   0x7f, 0x3e, 0x1c, 0x08};
"
}

#------------------------------------------------------------------------------
# tablelist::flat7x5Arrows
#------------------------------------------------------------------------------
proc tablelist::flat7x5Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp7x5_width 7
#define triangleUp7x5_height 5
static unsigned char triangleUp7x5_bits[] = {
   0x08, 0x1c, 0x3e, 0x7f, 0x7f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn7x5_width 7
#define triangleDn7x5_height 5
static unsigned char triangleDn7x5_bits[] = {
   0x7f, 0x7f, 0x3e, 0x1c, 0x08};
"
}

#------------------------------------------------------------------------------
# tablelist::flat7x7Arrows
#------------------------------------------------------------------------------
proc tablelist::flat7x7Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp7x7_width 7
#define triangleUp7x7_height 7
static unsigned char triangleUp7x7_bits[] = {
   0x08, 0x1c, 0x1c, 0x3e, 0x3e, 0x7f, 0x7f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn7x7_width 7
#define triangleDn7x7_height 7
static unsigned char triangleDn7x7_bits[] = {
   0x7f, 0x7f, 0x3e, 0x3e, 0x1c, 0x1c, 0x08};
"
}

#------------------------------------------------------------------------------
# tablelist::flat8x4Arrows
#------------------------------------------------------------------------------
proc tablelist::flat8x4Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp8x4_width 8
#define triangleUp8x4_height 4
static unsigned char triangleUp8x4_bits[] = {
   0x18, 0x3c, 0x7e, 0xff};
"
    image create bitmap triangleDn$w -data "
#define triangleDn8x4_width 8
#define triangleDn8x4_height 4
static unsigned char triangleDn8x4_bits[] = {
   0xff, 0x7e, 0x3c, 0x18};
"
}

#------------------------------------------------------------------------------
# tablelist::flat8x5Arrows
#------------------------------------------------------------------------------
proc tablelist::flat8x5Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp8x5_width 8
#define triangleUp8x5_height 5
static unsigned char triangleUp8x5_bits[] = {
   0x18, 0x3c, 0x7e, 0xff, 0xff};
"
    image create bitmap triangleDn$w -data "
#define triangleDn8x5_width 8
#define triangleDn8x5_height 5
static unsigned char triangleDn8x5_bits[] = {
   0xff, 0xff, 0x7e, 0x3c, 0x18};
"
}

#------------------------------------------------------------------------------
# tablelist::flat9x5Arrows
#------------------------------------------------------------------------------
proc tablelist::flat9x5Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp9x5_width 9
#define triangleUp9x5_height 5
static unsigned char triangleUp9x5_bits[] = {
   0x10, 0x00, 0x38, 0x00, 0x7c, 0x00, 0xfe, 0x00, 0xff, 0x01};
"
    image create bitmap triangleDn$w -data "
#define triangleDn9x5_width 9
#define triangleDn9x5_height 5
static unsigned char triangleDn9x5_bits[] = {
   0xff, 0x01, 0xfe, 0x00, 0x7c, 0x00, 0x38, 0x00, 0x10, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flat9x6Arrows
#------------------------------------------------------------------------------
proc tablelist::flat9x6Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp9x6_width 9
#define triangleUp9x6_height 6
static unsigned char triangleUp9x6_bits[] = {
   0x10, 0x00, 0x38, 0x00, 0x7c, 0x00, 0xfe, 0x00, 0xff, 0x01, 0xff, 0x01};
"
    image create bitmap triangleDn$w -data "
#define triangleDn9x6_width 9
#define triangleDn9x6_height 6
static unsigned char triangleDn9x6_bits[] = {
   0xff, 0x01, 0xff, 0x01, 0xfe, 0x00, 0x7c, 0x00, 0x38, 0x00, 0x10, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flat11x6Arrows
#------------------------------------------------------------------------------
proc tablelist::flat11x6Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp11x6_width 11
#define triangleUp11x6_height 6
static unsigned char triangleUp11x6_bits[] = {
   0x20, 0x00, 0x70, 0x00, 0xf8, 0x00, 0xfc, 0x01, 0xfe, 0x03, 0xff, 0x07};
"
    image create bitmap triangleDn$w -data "
#define triangleDn11x6_width 11
#define triangleDn11x6_height 6
static unsigned char triangleDn11x6_bits[] = {
   0xff, 0x07, 0xfe, 0x03, 0xfc, 0x01, 0xf8, 0x00, 0x70, 0x00, 0x20, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flat15x8Arrows
#------------------------------------------------------------------------------
proc tablelist::flat15x8Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp15x8_width 15
#define triangleUp15x8_height 8
static unsigned char triangleUp15x8_bits[] = {
   0x80, 0x00, 0xc0, 0x01, 0xe0, 0x03, 0xf0, 0x07, 0xf8, 0x0f, 0xfc, 0x1f,
   0xfe, 0x3f, 0xff, 0x7f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn15x8_width 15
#define triangleDn15x8_height 8
static unsigned char triangleDn15x8_bits[] = {
   0xff, 0x7f, 0xfe, 0x3f, 0xfc, 0x1f, 0xf8, 0x0f, 0xf0, 0x07, 0xe0, 0x03,
   0xc0, 0x01, 0x80, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle7x4Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle7x4Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp7x4_width 7
#define triangleUp7x4_height 4
static unsigned char triangleUp7x4_bits[] = {
   0x08, 0x1c, 0x36, 0x63};
"
    image create bitmap triangleDn$w -data "
#define triangleDn7x4_width 7
#define triangleDn7x4_height 4
static unsigned char triangleDn7x4_bits[] = {
   0x63, 0x36, 0x1c, 0x08};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle7x5Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle7x5Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp7x5_width 7
#define triangleUp7x5_height 5
static unsigned char triangleUp7x5_bits[] = {
   0x08, 0x1c, 0x3e, 0x77, 0x63};
"
    image create bitmap triangleDn$w -data "
#define triangleDn7x5_width 7
#define triangleDn7x5_height 5
static unsigned char triangleDn7x5_bits[] = {
   0x63, 0x77, 0x3e, 0x1c, 0x08};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle9x5Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle9x5Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp9x5_width 9
#define triangleUp9x5_height 5
static unsigned char triangleUp9x5_bits[] = {
   0x10, 0x00, 0x38, 0x00, 0x6c, 0x00, 0xc6, 0x00, 0x83, 0x01};
"
    image create bitmap triangleDn$w -data "
#define triangleDn9x5_width 9
#define triangleDn9x5_height 5
static unsigned char triangleDn9x5_bits[] = {
   0x83, 0x01, 0xc6, 0x00, 0x6c, 0x00, 0x38, 0x00, 0x10, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle9x6Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle9x6Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp9x6_width 9
#define triangleUp9x6_height 6
static unsigned char triangleUp9x6_bits[] = {
   0x10, 0x00, 0x38, 0x00, 0x7c, 0x00, 0xee, 0x00, 0xc7, 0x01, 0x83, 0x01};
"
    image create bitmap triangleDn$w -data "
#define triangleDn9x6_width 9
#define triangleDn9x6_height 6
static unsigned char triangleDn9x6_bits[] = {
   0x83, 0x01, 0xc7, 0x01, 0xee, 0x00, 0x7c, 0x00, 0x38, 0x00, 0x10, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle9x7Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle9x7Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp9x7_width 9
#define triangleUp9x7_height 7
static unsigned char triangleUp9x7_bits[] = {
   0x10, 0x00, 0x38, 0x00, 0x7c, 0x00, 0xfe, 0x00, 0xef, 0x01, 0xc7, 0x01,
   0x83, 0x01};
"
    image create bitmap triangleDn$w -data "
#define triangleDn9x7_width 9
#define triangleDn9x7_height 7
static unsigned char triangleDn9x7_bits[] = {
   0x83, 0x01, 0xc7, 0x01, 0xef, 0x01, 0xfe, 0x00, 0x7c, 0x00, 0x38, 0x00,
   0x10, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle10x6Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle10x6Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp10x6_width 10
#define triangleUp10x6_height 6
static unsigned char triangleUp10x6_bits[] = {
   0x30, 0x00, 0x78, 0x00, 0xfc, 0x00, 0xce, 0x01, 0x87, 0x03, 0x03, 0x03};
"
    image create bitmap triangleDn$w -data "
#define triangleDn10x6_width 10
#define triangleDn10x6_height 6
static unsigned char triangleDn10x6_bits[] = {
   0x03, 0x03, 0x87, 0x03, 0xce, 0x01, 0xfc, 0x00, 0x78, 0x00, 0x30, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::flatAngle10x7Arrows
#------------------------------------------------------------------------------
proc tablelist::flatAngle10x7Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp10x7_width 10
#define triangleUp10x7_height 7
static unsigned char triangleUp10x7_bits[] = {
   0x30, 0x00, 0x78, 0x00, 0xfc, 0x00, 0xfe, 0x01, 0xcf, 0x03, 0x87, 0x03,
   0x03, 0x03};
"
    image create bitmap triangleDn$w -data "
#define triangleDn10x7_width 10
#define triangleDn10x7_height 7
static unsigned char triangleDn10x6_bits[] = {
   0x03, 0x03, 0x87, 0x03, 0xcf, 0x03, 0xfe, 0x01, 0xfc, 0x00, 0x78, 0x00,
   0x30, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::photo7x7Arrows
#------------------------------------------------------------------------------
proc tablelist::photo7x7Arrows w {
    foreach dir {Up Dn} {
	image create photo triangle$dir$w
    }

    triangleUp$w put "
iVBORw0KGgoAAAANSUhEUgAAAAcAAAAHCAYAAADEUlfTAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAACXBIWXMAAA7DAAAOwwHHb6hk
AAAAGnRFWHRTb2Z0d2FyZQBQYWludC5ORVQgdjMuNS4xMDD0cqEAAABCSURBVBhXXY4BCgAgCAP9
T//R9/Ryc+ZEHCyb40CB3D1n6OAZuQOKi9klPhUsjNJ6VwUp+tOLopOGNkXncToWw6IPjiowJNyp
gu8AAAAASUVORK5CYII=
"
    triangleDn$w put "
iVBORw0KGgoAAAANSUhEUgAAAAcAAAAHCAYAAADEUlfTAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAP0lE
QVQYV22LgQ0AIAjD9g//yD1ejoBoFpRkISsUPsMzPwkOIcARmJlvKMGIJq9jt+Uem51Wscfe1hkq
8VAdWKBfMCRjQcZZAAAAAElFTkSuQmCC
"
}

#------------------------------------------------------------------------------
# tablelist::sunken8x7Arrows
#------------------------------------------------------------------------------
proc tablelist::sunken8x7Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp8x7_width 8
#define triangleUp8x7_height 7
static unsigned char triangleUp8x7_bits[] = {
   0x18, 0x3c, 0x3c, 0x7e, 0x7e, 0xff, 0xff};
"
    image create bitmap darkLineUp$w -data "
#define darkLineUp8x7_width 8
#define darkLineUp8x7_height 7
static unsigned char darkLineUp8x7_bits[] = {
   0x08, 0x0c, 0x04, 0x06, 0x02, 0x03, 0x00};
"
    image create bitmap lightLineUp$w -data "
#define lightLineUp8x7_width 8
#define lightLineUp8x7_height 7
static unsigned char lightLineUp8x7_bits[] = {
   0x10, 0x30, 0x20, 0x60, 0x40, 0xc0, 0xff};
"
    image create bitmap triangleDn$w -data "
#define triangleDn8x7_width 8
#define triangleDn8x7_height 7
static unsigned char triangleDn8x7_bits[] = {
   0xff, 0xff, 0x7e, 0x7e, 0x3c, 0x3c, 0x18};
"
    image create bitmap darkLineDn$w -data "
#define darkLineDn8x7_width 8
#define darkLineDn8x7_height 7
static unsigned char darkLineDn8x7_bits[] = {
   0xff, 0x03, 0x02, 0x06, 0x04, 0x0c, 0x08};
"
    image create bitmap lightLineDn$w -data "
#define lightLineDn8x7_width 8
#define lightLineDn8x7_height 7
static unsigned char lightLineDn8x7_bits[] = {
   0x00, 0xc0, 0x40, 0x60, 0x20, 0x30, 0x10};
"
}

#------------------------------------------------------------------------------
# tablelist::sunken10x9Arrows
#------------------------------------------------------------------------------
proc tablelist::sunken10x9Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp10x9_width 10
#define triangleUp10x9_height 9
static unsigned char triangleUp10x9_bits[] = {
   0x30, 0x00, 0x78, 0x00, 0x78, 0x00, 0xfc, 0x00, 0xfc, 0x00, 0xfe, 0x01,
   0xfe, 0x01, 0xff, 0x03, 0xff, 0x03};
"
    image create bitmap darkLineUp$w -data "
#define darkLineUp10x9_width 10
#define darkLineUp10x9_height 9
static unsigned char darkLineUp10x9_bits[] = {
   0x10, 0x00, 0x18, 0x00, 0x08, 0x00, 0x0c, 0x00, 0x04, 0x00, 0x06, 0x00,
   0x02, 0x00, 0x03, 0x00, 0x00, 0x00};
"
    image create bitmap lightLineUp$w -data "
#define lightLineUp10x9_width 10
#define lightLineUp10x9_height 9
static unsigned char lightLineUp10x9_bits[] = {
   0x20, 0x00, 0x60, 0x00, 0x40, 0x00, 0xc0, 0x00, 0x80, 0x00, 0x80, 0x01,
   0x00, 0x01, 0x00, 0x03, 0xff, 0x03};
"
    image create bitmap triangleDn$w -data "
#define triangleDn10x9_width 10
#define triangleDn10x9_height 9
static unsigned char triangleDn10x9_bits[] = {
   0xff, 0x03, 0xff, 0x03, 0xfe, 0x01, 0xfe, 0x01, 0xfc, 0x00, 0xfc, 0x00,
   0x78, 0x00, 0x78, 0x00, 0x30, 0x00};
"
    image create bitmap darkLineDn$w -data "
#define darkLineDn10x9_width 10
#define darkLineDn10x9_height 9
static unsigned char darkLineDn10x9_bits[] = {
   0xff, 0x03, 0x03, 0x00, 0x02, 0x00, 0x06, 0x00, 0x04, 0x00, 0x0c, 0x00,
   0x08, 0x00, 0x18, 0x00, 0x10, 0x00};
"
    image create bitmap lightLineDn$w -data "
#define lightLineDn10x9_width 10
#define lightLineDn10x9_height 9
static unsigned char lightLineDn10x9_bits[] = {
   0x00, 0x00, 0x00, 0x03, 0x00, 0x01, 0x80, 0x01, 0x80, 0x00, 0xc0, 0x00,
   0x40, 0x00, 0x60, 0x00, 0x20, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::sunken12x11Arrows
#------------------------------------------------------------------------------
proc tablelist::sunken12x11Arrows w {
    image create bitmap triangleUp$w -data "
#define triangleUp12x11_width 12
#define triangleUp12x11_height 11
static unsigned char triangleUp12x11_bits[] = {
   0x60, 0x00, 0xf0, 0x00, 0xf0, 0x00, 0xf8, 0x01, 0xf8, 0x01, 0xfc, 0x03,
   0xfc, 0x03, 0xfe, 0x07, 0xfe, 0x07, 0xff, 0x0f, 0xff, 0x0f};
"
    image create bitmap darkLineUp$w -data "
#define darkLineUp12x11_width 12
#define darkLineUp12x11_height 11
static unsigned char darkLineUp12x11_bits[] = {
   0x20, 0x00, 0x30, 0x00, 0x10, 0x00, 0x18, 0x00, 0x08, 0x00, 0x0c, 0x00,
   0x04, 0x00, 0x06, 0x00, 0x02, 0x00, 0x03, 0x00, 0x00, 0x00};
"
    image create bitmap lightLineUp$w -data "
#define lightLineUp12x11_width 12
#define lightLineUp12x11_height 11
static unsigned char lightLineUp12x11_bits[] = {
   0x40, 0x00, 0xc0, 0x00, 0x80, 0x00, 0x80, 0x01, 0x00, 0x01, 0x00, 0x03,
   0x00, 0x02, 0x00, 0x06, 0x00, 0x04, 0x00, 0x0c, 0xff, 0x0f};
"
    image create bitmap triangleDn$w -data "
#define triangleDn12x11_width 12
#define triangleDn12x11_height 11
static unsigned char triangleDn12x11_bits[] = {
   0xff, 0x0f, 0xff, 0x0f, 0xfe, 0x07, 0xfe, 0x07, 0xfc, 0x03, 0xfc, 0x03,
   0xf8, 0x01, 0xf8, 0x01, 0xf0, 0x00, 0xf0, 0x00, 0x60, 0x00};
"
    image create bitmap darkLineDn$w -data "
#define darkLineDn12x11_width 12
#define darkLineDn12x11_height 11
static unsigned char darkLineDn12x11_bits[] = {
   0xff, 0x0f, 0x03, 0x00, 0x02, 0x00, 0x06, 0x00, 0x04, 0x00, 0x0c, 0x00,
   0x08, 0x00, 0x18, 0x00, 0x10, 0x00, 0x30, 0x00, 0x20, 0x00};
"
    image create bitmap lightLineDn$w -data "
#define lightLineDn12x11_width 12
#define lightLineDn12x11_height 11
static unsigned char lightLineDn12x11_bits[] = {
   0x00, 0x00, 0x00, 0x0c, 0x00, 0x04, 0x00, 0x06, 0x00, 0x02, 0x00, 0x03,
   0x00, 0x01, 0x80, 0x01, 0x80, 0x00, 0xc0, 0x00, 0x40, 0x00};
"
}

#------------------------------------------------------------------------------
# tablelist::createSortRankImgs
#------------------------------------------------------------------------------
proc tablelist::createSortRankImgs win {
    image create bitmap sortRank1$win -data "
#define sortRank1_width 4
#define sortRank1_height 6
static unsigned char sortRank1_bits[] = {
   0x04, 0x06, 0x04, 0x04, 0x04, 0x04};
"
    image create bitmap sortRank2$win -data "
#define sortRank2_width 4
#define sortRank2_height 6
static unsigned char sortRank2_bits[] = {
   0x06, 0x09, 0x08, 0x04, 0x02, 0x0f};
"
    image create bitmap sortRank3$win -data "
#define sortRank3_width 4
#define sortRank3_height 6
static unsigned char sortRank3_bits[] = {
   0x0f, 0x08, 0x06, 0x08, 0x09, 0x06};
"
    image create bitmap sortRank4$win -data "
#define sortRank4_width 4
#define sortRank4_height 6
static unsigned char sortRank4_bits[] = {
   0x04, 0x06, 0x05, 0x0f, 0x04, 0x04};
"
    image create bitmap sortRank5$win -data "
#define sortRank5_width 4
#define sortRank5_height 6
static unsigned char sortRank5_bits[] = {
   0x0f, 0x01, 0x07, 0x08, 0x09, 0x06};
"
    image create bitmap sortRank6$win -data "
#define sortRank6_width 4
#define sortRank6_height 6
static unsigned char sortRank6_bits[] = {
   0x06, 0x01, 0x07, 0x09, 0x09, 0x06};
"
    image create bitmap sortRank7$win -data "
#define sortRank7_width 4
#define sortRank7_height 6
static unsigned char sortRank7_bits[] = {
   0x0f, 0x08, 0x04, 0x04, 0x02, 0x02};
"
    image create bitmap sortRank8$win -data "
#define sortRank8_width 4
#define sortRank8_height 6
static unsigned char sortRank8_bits[] = {
   0x06, 0x09, 0x06, 0x09, 0x09, 0x06};
"
    image create bitmap sortRank9$win -data "
#define sortRank9_width 4
#define sortRank9_height 6
static unsigned char sortRank9_bits[] = {
   0x06, 0x09, 0x09, 0x0e, 0x08, 0x06};
"
}

#------------------------------------------------------------------------------
# tablelist::createCheckbuttonImgs
#------------------------------------------------------------------------------
proc tablelist::createCheckbuttonImgs {} {
    variable checkedImg [image create bitmap tablelist_checkedImg -data "
#define checked_width 9
#define checked_height 9
static unsigned char checked_bits[] = {
   0x00, 0x00, 0x80, 0x00, 0xc0, 0x00, 0xe2, 0x00, 0x76, 0x00, 0x3e, 0x00,
   0x1c, 0x00, 0x08, 0x00, 0x00, 0x00};
"]

    variable uncheckedImg [image create bitmap tablelist_uncheckedImg -data "
#define unchecked_width 9
#define unchecked_height 9
static unsigned char unchecked_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
"]
}

#------------------------------------------------------------------------------
# tablelist::adwaitaTreeImgs
#------------------------------------------------------------------------------
proc tablelist::adwaitaTreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel
		  collapsedAct expandedAct collapsedSelAct expandedSelAct} {
	variable adwaita_${mode}Img \
		 [image create photo tablelist_adwaita_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_adwaita_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwQAADsEBuJFr7QAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAVUlE
QVQoU2P4//8/yRirICGMymFgCELm48KoHAaGCiAORxbDhlE5EE3FhDSiciCaCGpE5SA0wTQmIcvD
1aFwKNREsvPICgiSg5z0yCUWYxXEj/8zAACoLdL8k+To/wAAAABJRU5ErkJggg==
"
	tablelist_adwaita_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwQAADsEBuJFr7QAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAWklE
QVQoU5WLQQ7AIAgEufQbfrIXf0+LWhLrxG1J5sDAmLv/BqUCpQKlAqUiptzUD5SMRhnhOY5vwmeQ
0SZcgvY7LXOIQftbRA8jwiBgaXaQf0CpQKlAucftAn9twSV64sz7AAAAAElFTkSuQmCC
"
	tablelist_adwaita_collapsedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwQAADsEBuJFr7QAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAUElE
QVQoU2P4//8/yRirICGMLhCLxseK0QU6gTgFTQwDowuANLUAMV6N6AIgTQQ1ogvANME0FgExuhrq
aiLZeWQFBMlBTlbkEoWxCuLH/xkA08cuiUfbFjwAAAAASUVORK5CYII=
"
	tablelist_adwaita_expandedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwQAADsEBuJFr7QAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAWElE
QVQoU5XLMQ6AMBADwTS8hK/S8OrDLjiBsoqhGERW51FVv2FMMCYYE4yJP7ucH/iuR/fwEDp274H1
j9BwGtjrIc8hDmwK4kOPcGAYZYPWMCYYE4xrNS6APy6jKYbrTgAAAABJRU5ErkJggg==
"
	tablelist_adwaita_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwAAADsABataJCQAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAV0lE
QVQoU2P4//8/yRirICGMymFg6EHm48KoHAaGs0A8BVkMG0blQDQdIaQRlQPRRFAjKgehCYSPAvFy
ZHm4OhQOhZpIdh5ZAUFykJMeucRirIL48X8GANuH2/YmUibsAAAAAElFTkSuQmCC
"
	tablelist_adwaita_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwAAADsABataJCQAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAW0lE
QVQoU5WLMQ7AMAjEWPue/H/smDfRkqRIaaxci+QBg83df4NSgVKBUoFSEVNu6gdKRqOM8BzHN+Ez
yGgTLkH7nZY5xKD9LaKHEWEQsDQ7yD+gVKBUoNzjdgEnwso211sfFwAAAABJRU5ErkJggg==
"
	tablelist_adwaita_collapsedSelActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOvwAADr8BOAVTJAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAUUlE
QVQoU2P4//8/yRirICGMLrAOjY8VowuAwE4gRhdHwegCIPAZiPFqRBeAAbwa0QWQwTcgvgjE6Gqo
q4lk55EVECQHOVmRSxTGKogf/2cAACEfOvsNAw2AAAAAAElFTkSuQmCC
"
	tablelist_adwaita_expandedSelActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwAAADsABataJCQAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAWElE
QVQoU5XLwQ2AMBADwRSQnui/Ib6H/eBElBWGSIPCKh5V9RvGBGOCMcGY+HPIl+N3PbqHp9Bx74H1
RWi4DWz5kecQB7YF8UMfHBhGmdAaxgRjgvFdjQtoujswws5A0wAAAABJRU5ErkJggg==
"
    } else {
	tablelist_adwaita_collapsedImg put "
R0lGODlhDQAOAMIGAAAAAIeHh4yMjJ2dnaioqK2trf///////yH5BAEKAAcALAAAAAANAA4AAAMd
eLrc/qdAFshUQdgZ8n5dNkChMIIep13VFbkwnAAAOw==
"
	tablelist_adwaita_expandedImg put "
R0lGODlhDQAOAKEDAAAAAIeHh4yMjP///yH5BAEKAAMALAAAAAANAA4AAAIWnI+py+0fopRJzCCW
jZnZ3gTPSJZNAQA7
"
	tablelist_adwaita_collapsedSelImg put "
R0lGODlhDQAOAKECAAAAAMzMzP///////yH5BAEKAAAALAAAAAANAA4AAAIXhI+pC8EY3Gtxxsou
Vlry+4Chl03maRQAOw==
"
	tablelist_adwaita_expandedSelImg put "
R0lGODlhDQAOAKECAAAAAMzMzP///////yH5BAEKAAAALAAAAAANAA4AAAIRhI+py+0fopRpUmXb
1a/73xQAOw==
"
	tablelist_adwaita_collapsedActImg put "
R0lGODlhDQAOAMIHAAAAADIyMjo6Ojs7O1hYWGtra3Nzc////yH5BAEKAAcALAAAAAANAA4AAAMd
eLrc/sdAFspUYdgZ8n5dIBBQOJYep13VFbkwnAAAOw==
"
	tablelist_adwaita_expandedActImg put "
R0lGODlhDQAOAKEDAAAAADIyMjo6Ov///yH5BAEKAAMALAAAAAANAA4AAAIWnI+py+0fopRJzCCW
jZnZ3gTPSJZNAQA7
"
	tablelist_adwaita_collapsedSelActImg put "
R0lGODlhDQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAANAA4AAAIXhI+pC8EY3Gtxxsou
Vlry+4Chl03maRQAOw==
"
	tablelist_adwaita_expandedSelActImg put "
R0lGODlhDQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAANAA4AAAIRhI+py+0fopRpUmXb
1a/73xQAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::ambianceTreeImgs
#------------------------------------------------------------------------------
proc tablelist::ambianceTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable ambiance_${mode}Img \
		 [image create photo tablelist_ambiance_${mode}Img]
    }

    tablelist_ambiance_collapsedImg put "
R0lGODlhEwAPAKUxAAAAADw7N9/Wxd/Wxt/WyODYyeLZyuHazeTdz+Pd0eTd0uXf0+Xf1efg1OXg
1ujh0+jg1Onj1+nj2Ork2O3m3Ozm3e7p4e/q4e7s5u/s6PHs5PHs5fHs5vHu6fPw6vTw6vTw6/bz
7vbz7/b07vb07/b08Pb08fj28/n49Pr59fr59vv5+Pv6+Pr6+vz6+fz7+v39/f//////////////
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAaiwN/v
ICgajQehUljotGDQKKyVKSyHmRXL5Xp5uawVJqkUmE4oVCqlWqdPJcFSEBKRSiZTIF8ijUhyZR8e
HR4gIAGHHh4fH4FCAhySHBobARsbkxyPPwIXFxYBoqMBnxecAhUVFKoVAa2tqBMRErUSAbYRExOo
DxC/vwHAEA0PqAoIycrLCAucBwwG0tPUBg5kSgUJBAPd3gMECVZXQ0fm2EpBADs=
"
    tablelist_ambiance_expandedImg put "
R0lGODlhEwAPAKUyAAAAADw7N9/Wxd/Wxt/WyODYyeLZyuHazeTdz+Pd0eTd0uXf0+Xf1efg1OXg
1ujh0+jg1Onj1+nj2Ork2O3m3Ozm3e7p4e/q4e7s5u/s6PHs5PHs5fHs5vHu6fPw6vTw6vTw6/bz
7vbz7/b07vb07/b08Pb08fj18fj28/n49Pr59fr59vv5+Pv6+Pr6+vz6+fz7+v39/f//////////
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAacwN/v
ICgajQehUljouGLQaMyVKSyHGVbr9YJ5uS0WJqkUmFCplEq1WqdRJcFSEBKRSibTKV8ijUhyZR8e
HR4gh4ceHh8fgUICHJEcGhscG5WSjj8CFxcWAaChAZ0XmgIVFRSoq6wVphMRErKzshETE6YPELu8
vQ0PpgoIw8TFCAuaBwwGzM3OBg5kSgUJBAPX2AMECVZXQ0fg0kpBADs=
"
}

#------------------------------------------------------------------------------
# tablelist::aquaTreeImgs
#------------------------------------------------------------------------------
proc tablelist::aquaTreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable aqua_${mode}Img \
		 [image create photo tablelist_aqua_${mode}Img]
    }

    variable pngSupported
    variable winSys
    scan $::tcl_platform(osVersion) "%d" majorOSVersion
    if {[string compare $winSys "aqua"] == 0 && $majorOSVersion > 10} {
	set osVerPost10 1
    } else {
	set osVerPost10 0
    }

    if {$pngSupported} {
	if {$osVerPost10} {
	    tablelist_aqua_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAAOCAYAAADABlfOAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwgAADsIBFShKgAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAaklE
QVQ4T2MYBSjg////DMXFxQ+B2A/GR6bJBkAD/0PxViBWAhmICxMNkAwF4Z9AXIXNQBAmGqAZCsNX
gdie2obCcAC6wUQZjsUgEMZwKUkAzTCMMCULIBmIEvtkAZhmoEHUT6eDEDAwAACJ1s4t5kg57QAA
AABJRU5ErkJggg==
"
	    tablelist_aqua_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAAOCAYAAADABlfOAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwgAADsIBFShKgAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAgElE
QVQ4T82Quw3AIAxEmYVF2ABlFzr2YhQGYIxU5E5yJIsiiQkFTzrxke8VdlvQe5ebgbfSPtKUUkP6
Q5qMfgelOEjGRBm1gWIZRHeKjNjgzlD2yKlkDN9+aqdExFkJmTwlZEkHoirCqv/N6DJkQaRB//8G
woPnMiFZJtLYpc5dCuytTkpAX+QAAAAASUVORK5CYII=
"
	} else {
	    tablelist_aqua_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAAOCAYAAADABlfOAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwgAADsIBFShKgAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAVUlE
QVQ4T2MYBRigra3tIRD7QbnUAUAD/0PxViBWggpTBpAMBeGfQFwFlSIfoBkKw1eB2B6qhHSAZhg6
DoAqIw1gMQiEqepSqocpVWOf+ul0EAIGBgD3QGlokXBrxgAAAABJRU5ErkJggg==
"
	    tablelist_aqua_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAAOCAYAAADABlfOAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwgAADsIBFShKgAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAbklE
QVQ4T2MYBbQHbW1tD4H4Px78EKqUeADU5IdmCDr2gyolDQA1bkUzCIa3QpWQDoCalYD4J5JhIAzi
K/3//58BhMkCQAOqkAwE4SqoFGUAaNBVqIFXoUKUA6Bh9lBD7aFC1AFAAwOgzGEHGBgA7s9vYvwQ
9+MAAAAASUVORK5CYII=
"
	}

	tablelist_aqua_collapsedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAAOCAYAAADABlfOAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAVElE
QVQ4T2MYBRjg////N4HYEcqlDgAaCANLgFgCKkwZgJgHB5+AOAsqRT6AmIUBTgOxKVQJ6QBiBk7g
DFVGGoBqRgdUdSnVw5SqsU/9dDoIAQMDAK4npwmnhxytAAAAAElFTkSuQmCC
"
	tablelist_aqua_expandedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAAOCAYAAADABlfOAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAbElE
QVQ4T2MYBbQH////vwnE+MBNqFLiAVCTI0QvTuAIVUoaAGpcAtGPAZZAlZAOgJolgPgT2BgEAPEl
oErIA0ADssBGIUAWVIoyADToNMS8/6ehQpQDoGGmEDP/m0KFqAOABjpDmcMOMDAAAJg2pwkFRUVJ
AAAAAElFTkSuQmCC
"
    } else {
	if {$osVerPost10} {
	    tablelist_aqua_collapsedImg put "
R0lGODlhFQAOAMIGAAAAAHNzc3Z2doODg4qKipubm////////yH5BAEKAAcALAAAAAAVAA4AAAMi
eLrc/jDKqQaFIZTbchDc4mVEOHrcWaYZGB7Z9h7WbN9KAgA7
"
	    tablelist_aqua_expandedImg put "
R0lGODlhFQAOAMIGAAAAAHNzc3Z2doODg4qKipubm////////yH5BAEKAAcALAAAAAAVAA4AAAMg
eLrc/jDKSeUIOIdRda5H4RXgIWRCqXzqQQREu8p0LScAOw==
"
	} else {
	    tablelist_aqua_collapsedImg put "
R0lGODlhFQAOAMIGAAAAAIaGhoiIiJSUlJmZmampqf///////yH5BAEKAAcALAAAAAAVAA4AAAMi
eLrc/jDKqQaFIZTbchDc4mVEOHrcWaYZGB7Z9h7WbN9KAgA7
"
	    tablelist_aqua_expandedImg put "
R0lGODlhFQAOAMIGAAAAAIaGhoiIiJSUlJmZmampqf///////yH5BAEKAAcALAAAAAAVAA4AAAMg
eLrc/jDKSeUIOIdRda5H4RXgIWRCqXzqQQREu8p0LScAOw==
"
	}

	tablelist_aqua_collapsedSelImg put "
R0lGODlhFQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAAVAA4AAAIchI+py+1vAmShzlTt
jVnPnl2gJIYbYJ7kybZIAQA7
"
	tablelist_aqua_expandedSelImg put "
R0lGODlhFQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAAVAA4AAAIahI+py+0PXZiUxmov
DtHgfmQgII7ciKYqUgAAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::baghiraTreeImgs
#------------------------------------------------------------------------------
proc tablelist::baghiraTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable baghira_${mode}Img \
		 [image create photo tablelist_baghira_${mode}Img]
    }

    tablelist_baghira_collapsedImg put "
R0lGODlhEAAOAIABAAAAAP///yH5BAEKAAEALAAAAAAQAA4AAAIVjI+py+1vADxAzmofzg1f7oDT
SEIFADs=
"
    tablelist_baghira_expandedImg put "
R0lGODlhEAAOAIABAAAAAP///yH5BAEKAAEALAAAAAAQAA4AAAITjI+py+0P4wK0Amfvq1LLD4ZO
AQA7
"
}

#------------------------------------------------------------------------------
# tablelist::bicolor1TreeImgs
#------------------------------------------------------------------------------
proc tablelist::bicolor1TreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable bicolor1_${mode}Img \
		 [image create photo tablelist_bicolor1_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_bicolor1_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAJCAYAAAAGuM1UAAAAMElEQVQY02NgQIB6BiIAExq/nlQN
BDUx4RCvJ1UDTk34NDSSoqGRFCc1MhAJiIoHAPzJBIzdNMy+AAAAAElFTkSuQmCC
"
	tablelist_bicolor1_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAJCAYAAAAGuM1UAAAALklEQVQY02NgoDVgZGBgqCdCXSOy
BgYCmhrRbWDAo6kRm5MYcGhqJNZf9QwDCgAizASENAzPWgAAAABJRU5ErkJggg==
"
    } else {
	tablelist_bicolor1_collapsedImg put "
R0lGODlhDAAJAIABAH9/f////yH5BAEKAAEALAAAAAAMAAkAAAISTGCpBrja3Dtx0vqiXHg2y4AF
ADs=
"
	tablelist_bicolor1_expandedImg put "
R0lGODlhDAAJAIABAH9/f////yH5BAEKAAEALAAAAAAMAAkAAAIPjI+pB+2OHkxyhWmB3RwVADs=
"
    }

    tablelist_bicolor1_collapsedSelImg put "
R0lGODlhDAAJAIAAAP///////yH5BAEKAAEALAAAAAAMAAkAAAISTGCpBrja3Dtx0vqiXHg2y4AF
ADs=
"
    tablelist_bicolor1_expandedSelImg put "
R0lGODlhDAAJAIAAAP///////yH5BAEKAAEALAAAAAAMAAkAAAIPjI+pB+2OHkxyhWmB3RwVADs=
"
}

#------------------------------------------------------------------------------
# tablelist::bicolor2TreeImgs
#------------------------------------------------------------------------------
proc tablelist::bicolor2TreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable bicolor2_${mode}Img \
		 [image create photo tablelist_bicolor2_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_bicolor2_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA4AAAALCAYAAABPhbxiAAAAOUlEQVQoz2NgQAVNDEQCJixiTeRq
JEozEx65JnI14tXMRIR3msjVWEeOxjpynFpHTuDUMZAIiE45APJdBZkq7zr6AAAAAElFTkSuQmCC
"
	tablelist_bicolor2_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA4AAAALCAYAAABPhbxiAAAANklEQVQoz2NgoDdgZGBgqCdBfSOy
RgYiNTei28hAhOZGbE5lIKC5EZcfGfBobiQ10OoZhg8AALhPBYVNoXj+AAAAAElFTkSuQmCC
"
    } else {
	tablelist_bicolor2_collapsedImg put "
R0lGODlhDgALAIABAH9/f////yH5BAEKAAEALAAAAAAOAAsAAAIXjGGpCrjf3EtRzmoXzrTOE30g
p5GaGBQAOw==
"
	tablelist_bicolor2_expandedImg put "
R0lGODlhDgALAIABAH9/f////yH5BAEKAAEALAAAAAAOAAsAAAITjI+pC+0PEHxqRkaXcVr2D4Za
AQA7
"
    }

    tablelist_bicolor2_collapsedSelImg put "
R0lGODlhDgALAIAAAP///////yH5BAEKAAEALAAAAAAOAAsAAAIXjGGpCrjf3EtRzmoXzrTOE30g
p5GaGBQAOw==
"
    tablelist_bicolor2_expandedSelImg put "
R0lGODlhDgALAIAAAP///////yH5BAEKAAEALAAAAAAOAAsAAAITjI+pC+0PEHxqRkaXcVr2D4Za
AQA7
"
}

#------------------------------------------------------------------------------
# tablelist::bicolor3TreeImgs
#------------------------------------------------------------------------------
proc tablelist::bicolor3TreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable bicolor3_${mode}Img \
		 [image create photo tablelist_bicolor3_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_bicolor3_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABEAAAANCAYAAABPeYUaAAAAQ0lEQVQoz2NgQAX1DGQAJixi9dQw
hGSDmPDI1VPDEKINYiJCTT01DCFoELGGNFJqSCOl3mmkNGAbKY3iRgYKAFl5BwCpnQaUXzVUsAAA
AABJRU5ErkJggg==
"
	tablelist_bicolor3_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABEAAAANCAYAAABPeYUaAAAAPUlEQVQoz+XRMQ4AIAhD0e/JSW/u
blBAN+nOCxT4KgOwizmtCEVI3iYUIO3OIQnp1AkJSFGxBJBePmf0zAT3jwaGIuX2/gAAAABJRU5E
rkJggg==
"
    } else {
	tablelist_bicolor3_collapsedImg put "
R0lGODlhEQANAIABAH9/f////yH5BAEKAAEALAAAAAARAA0AAAIcjGGpe8gfgIRMTprsxXrD7lUd
FmlkGX6pemZtAQA7
"
	tablelist_bicolor3_expandedImg put "
R0lGODlhEQANAIABAH9/f////yH5BAEKAAEALAAAAAARAA0AAAIXjI+py60Ao4xp2mUpyy7Mbmig
N5bmeRQAOw==
"
    }

    tablelist_bicolor3_collapsedSelImg put "
R0lGODlhEQANAIAAAP///////yH5BAEKAAEALAAAAAARAA0AAAIcjGGpe8gfgIRMTprsxXrD7lUd
FmlkGX6pemZtAQA7
"
    tablelist_bicolor3_expandedSelImg put "
R0lGODlhEQANAIAAAP///////yH5BAEKAAEALAAAAAARAA0AAAIXjI+py60Ao4xp2mUpyy7Mbmig
N5bmeRQAOw==
"
}

#------------------------------------------------------------------------------
# tablelist::bicolor4TreeImgs
#------------------------------------------------------------------------------
proc tablelist::bicolor4TreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable bicolor4_${mode}Img \
		 [image create photo tablelist_bicolor4_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_bicolor4_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABcAAAARCAYAAAA2cze9AAAAUklEQVQ4y7WUSQoAMAgDxY+H/Lyn
nkrpopOjygTcIlYpmpSbuEh4i0Ee8iLhJYO8rBMJ/zLIx3qR8CeDH7gpuKm2mBqoqVU0dUSmzr8E
xr7h1ADeYgic3eAtOQAAAABJRU5ErkJggg==
"
	tablelist_bicolor4_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABcAAAARCAYAAAA2cze9AAAATElEQVQ4y+2UiQ0AIAgDz8lJN3cC
lUdNTOwAPVIK8HVbDbANPhqZUwRoNjkFgFaxkATIkzkJgLwLJQhQpC0EAIpWESdAJ27B/jt4Rx1i
8QiI+CHjPQAAAABJRU5ErkJggg==
"
    } else {
	tablelist_bicolor4_collapsedImg put "
R0lGODlhFwARAIABAH9/f////yH5BAEKAAEALAAAAAAXABEAAAInjAOnywrZ4npQSlotw1kf3nlg
aI1kZJ7b6H1g62Jw/My0HeOu/ukFADs=
"
	tablelist_bicolor4_expandedImg put "
R0lGODlhFwARAIABAH9/f////yH5BAEKAAEALAAAAAAXABEAAAIhjI+py+0PYwC02ksX3pnx+3xd
yEkTZhpgqo7s9MbyTCsFADs=
"
    }

    tablelist_bicolor4_collapsedSelImg put "
R0lGODlhFwARAIAAAP///////yH5BAEKAAEALAAAAAAXABEAAAInjAOnywrZ4npQSlotw1kf3nlg
aI1kZJ7b6H1g62Jw/My0HeOu/ukFADs=
"
    tablelist_bicolor4_expandedSelImg put "
R0lGODlhFwARAIAAAP///////yH5BAEKAAEALAAAAAAXABEAAAIhjI+py+0PYwC02ksX3pnx+3xd
yEkTZhpgqo7s9MbyTCsFADs=
"
}

#------------------------------------------------------------------------------
# tablelist::classic1TreeImgs
#------------------------------------------------------------------------------
proc tablelist::classic1TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable classic1_${mode}Img \
		 [image create photo tablelist_classic1_${mode}Img]
    }

    tablelist_classic1_collapsedImg put "
R0lGODlhDAAJAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAMAAkAAAIdXI4xa+Iv1AoPPNmc
dZiC/0UMpV1jZU5QOiUHMxQAOw==
"
    tablelist_classic1_expandedImg put "
R0lGODlhDAAJAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAMAAkAAAIbXI4xa+Iv1ArwyVYj
o6B3PWUgVl1UdhnJwQwFADs=
"
}

#------------------------------------------------------------------------------
# tablelist::classic2TreeImgs
#------------------------------------------------------------------------------
proc tablelist::classic2TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable classic2_${mode}Img \
		 [image create photo tablelist_classic2_${mode}Img]
    }

    tablelist_classic2_collapsedImg put "
R0lGODlhDgALAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAOAAsAAAIiXI44a+L/AgsQQLno
s3HW6wHiaGHNBmZfp6LsCb1GkjBDAQA7
"
    tablelist_classic2_expandedImg put "
R0lGODlhDgALAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAOAAsAAAIhXI44a+L/AguwykVr    
nHpjAYQiIFxNV3KomXUsmk5JwgwFADs=
"
}

#------------------------------------------------------------------------------
# tablelist::classic3TreeImgs
#------------------------------------------------------------------------------
proc tablelist::classic3TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable classic3_${mode}Img \
		 [image create photo tablelist_classic3_${mode}Img]
    }

    tablelist_classic3_collapsedImg put "
R0lGODlhEQANAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAARAA0AAAItXI4ZwxwCoxSrvTmr
myA3w3lWKGmgAKRqR31XxEbmC8XQTMouJm687lIoPoMCADs=
"
    tablelist_classic3_expandedImg put "
R0lGODlhEQANAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAARAA0AAAIoXI4ZwxwCoxSrvTmr
w7kZLmkfCIkXgKZA6V2kSbJWTLU0HIuGonhDAQA7
"
}

#------------------------------------------------------------------------------
# tablelist::classic4TreeImgs
#------------------------------------------------------------------------------
proc tablelist::classic4TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable classic4_${mode}Img \
		 [image create photo tablelist_classic4_${mode}Img]
    }

    tablelist_classic4_collapsedImg put "
R0lGODlhFwASAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAXABIAAAJGXI6pMe0hopxUMGeq
lvdpAGhdA1WgiGVmWI0qdbZpCbOUW4L6rkd4xAuyfisUhjaJ3WYf24RYM3qKsuNmA70+U4aF98At
AAA7
"
    tablelist_classic4_expandedImg put "
R0lGODlhFwASAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAXABIAAAI9XI6pMe0hopxUMGeq
lvft3TXQV4UZSZkjymEnG6kRQNc2HbvjzQM5toLJYD8P0aI7IoHKIdEpdBkW1IO0AAA7
"
}

#------------------------------------------------------------------------------
# tablelist::dustTreeImgs
#------------------------------------------------------------------------------
proc tablelist::dustTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable dust_${mode}Img \
		 [image create photo tablelist_dust_${mode}Img]
    }

    tablelist_dust_collapsedImg put "
R0lGODlhEwAPAKU0AAAAADIyMrConLGpncC6scC7ssG8s8K8tMK9tdDMxtDMx9LOyNrVztvVz9vW
ztvWz9vX0NzW0N3Y0d/a0uDd1uHe1+Lf2OPg2uTh2+Xj3efk3+jl4Ojm4enm4unn4+nn5Orn5evo
5Ovo5evq5ezp5e3q5u3q5+7s6O/t6e7t6vDu6/Hv7PHv7fLw7PLw7vT08vf39fj39fn49vn49///
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAakwB9h
ICgajQPCb7k0LF6wmGxGlcVgL8WB+RuwSieUatVaqVCnkWvAFbA6IVLJRC+RQh2WoJ3CZDQbHAEc
GxoZGCl7TAImFBUWFxcBkRYVFCaKSwIiEp0SEwETnhIimT8CHQwRAaytAQ8PHaaosA8ODwENtbGz
Hru4vx69v6+7wm0hEcrLzBEhpgMeEM3MEB5sTAcKICLd3t4fCQhcQkRHRwMF5EEAOw==
"
    tablelist_dust_expandedImg put "
R0lGODlhEwAPAKU0AAAAADIyMrConLGpncS+tcS/tsbBuMfBucfCucfCutfTzdjUztnUz9vWztvW
z9vX0NzW0N3Y0d/a0t/a0+Dd1uHe1+Lf2OPg2uTh2+Xj3efk3+jl4Ojm4enm4unn4+vo5Ovo5evp
5uvq5ezp5e3q5u3q5+7s6O/t6e7t6vDu6/Hv7PLv7fLw7PHw7fLx7vX08vf39fj39fn49vn49///
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAagwB9h
ICgajQPCb7k0LF6wmGxGlcVgLwWC+Ru0SKZTSsVSpU4mkWvAFaw6nxGpRCeNPp2VoI3CZDQbHIIb
GhkYKHtMAiUUFRYXFxiQFhUUJYlLAiARnBESExKdESCYPwIdCxABq6wBDg4dpaevDg2vDLSwsh65
va8eu769wG0fEMfIyRAfpQMfD8rJDx9sTAcMISDa29wLCVxCREdHAwXgQQA7
"
}

#------------------------------------------------------------------------------
# tablelist::dustSandTreeImgs
#------------------------------------------------------------------------------
proc tablelist::dustSandTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable dustSand_${mode}Img \
		 [image create photo tablelist_dustSand_${mode}Img]
    }

    tablelist_dustSand_collapsedImg put "
R0lGODlhEwAPAKU1AAAAADIyMpuWjJyXjrSxqbWxqre0rbi1rrm2r8K+tsO+t8TAuMXBusbCu8nF
vcnGvsrHv8vHwMnGwcrIwczIwMzIwc3Jw87LxMzKxc/MxdDMxdDMx9HOx9HOyNLPydPPytPQydPQ
y9TRy9TRzNXTzNXSzdfTztbUzNbUzdfVz9nV0NjW0NnW0drY097c2eDe2eXi3uXj3+jm4+nn5Oro
5f///////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAakwB9h
ICgajQPCb7k0TGAy2WxGm0ZjkgPzN3iVSibVirVSmUqj12ArcG06H9FoLvp0Ni4Bu1WxXDIaARoZ
FxYVLXpMAikODxARFAEUERAPDimJSwIhDJ0MDQENngwhmT8CHAkKAaytAQoKHKaosLAJAaq1smwc
tbCvvruKHb6rxR2zHgvLzM0LHqYDJc7UJGtMBxgoINzd3ScYCFs/BURHRwMF40EAOw==
"
    tablelist_dustSand_expandedImg put "
R0lGODlhEwAPAKU3AAAAADIyMpuWjJyXjrSxqbWxqre0rbi1rrm2r8K+tsO+t8TAuMXBusbCu8bC
vMnFvcnGvsrHv8vHwMnGwcrIwczIwMzIwc3Jw87LxMzKxc/Mxc/MxtDMxdDMx9HOx9HOyNLPydPP
ytPQydPQy9TRy9TRzNXTzNXSzdfTztbUzNbUzdfVz9nV0NjW0NnW0drY097c2eDe2eXi3uXj3+jm
4+nn5Oro5f///////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAahwB9h
ICgajQPCb7k0UGQ0Wq1mm0ZnkwPzN4idTihWy9VioU6l2GArgHU+IVJpTgp9OjAB+2W5YDQcGxwa
GBcWL3pMAisPEBESFRYVEhEQDyuJSwIjDJ0MDQ4NngwjmT8CHgkKAaytAQoKHqaosLAJt7Wxsx65
vbCybB++vR+zIAvIycoLIKYDJ8vRJmtMBxkqItna2ikZCFs/BURHRwMF4EEAOw==
"
}

#------------------------------------------------------------------------------
# tablelist::gtkTreeImgs
#------------------------------------------------------------------------------
proc tablelist::gtkTreeImgs {} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable gtk_${mode}Img \
		 [image create photo tablelist_gtk_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_gtk_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAABGdBTUEAALGPC/xhBQAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMtfuaUMAAABTSURBVDhPtdLBDQAgCANA376YgTmcj8UY
TG2iiV9t7QAX0lLKxzSJbWZ9QjwGyN15DFBm8hgghMY2RGMnBCwi+hqgXq0pv0jSEY2gA+kfST77
FRmz+lZUJ0vkXgAAAABJRU5ErkJggg==
"
	tablelist_gtk_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAABGdBTUEAALGPC/xhBQAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMtfuaUMAAABRSURBVDhPY2AYBXQNARsBAYH/xGKgy2zw
uc5GSUnp/+HDh/9jAyBxkDwhQ2AWYDWMVEOwGkauISiGtbW1keQdXOEGjgBiw4RQ0uAipGBwywMA
wOZWVA37acsAAAAASUVORK5CYII=
"
	tablelist_gtk_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuND6NzHYAAABLSURBVDhPY2CgIbChitkCAgL/gQZRbhjI
IAkJCcoNAxlEFcNgBlFsGLJBFBmGbhCMD4wALpJikyYuoij2qBprFLkEFpBUS9nkZg8AkLUuN8tq
YDwAAAAASUVORK5CYII=
"
	tablelist_gtk_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuND6NzHYAAABCSURBVDhPY2AYBXQNgUwBAYH/xGKgyzLx
uY4owwgZArMAr2HEGoLXMFINwTBMSUnpP7mGoBhGqSEww0TomnaobhkAI24v01R6oWMAAAAASUVO
RK5CYII=
"
    } else {
	tablelist_gtk_collapsedImg put "
R0lGODlhEgAOAMIFAAAAABAQECIiIoaGhsPDw////////////yH5BAEKAAcALAAAAAASAA4AAAMi
eLrc/pCFCIOgLpCLVyhbp3wgh5HFMJ1FKX7hG7/mK95MAgA7
"
	tablelist_gtk_expandedImg put "
R0lGODlhEgAOAMIFAAAAABAQECIiIoaGhsPDw////////////yH5BAEKAAcALAAAAAASAA4AAAMg
eLrc/jDKSWu4OAcoSPkfIUgdKFLlWQnDWCnbK8+0kgAAOw==
"
	tablelist_gtk_collapsedActImg put "
R0lGODlhEgAOAKEDAAAAABAQEBgYGP///yH5BAEKAAMALAAAAAASAA4AAAIdnI+pyxjNgoAqSOrs
xMNq7nlYuFFeaV5ch47raxQAOw==
"
	tablelist_gtk_expandedActImg put "
R0lGODlhEgAOAMIFAAAAABAQECIiIoaGhsPDw////////////yH5BAEKAAcALAAAAAASAA4AAAMg
eLrc/jDKSWu4OAcoSPkfIUgdKFLlWQnDWCnbK8+0kgAAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::klearlooksTreeImgs
#------------------------------------------------------------------------------
proc tablelist::klearlooksTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable klearlooks_${mode}Img \
		 [image create photo tablelist_klearlooks_${mode}Img]
    }

    tablelist_klearlooks_collapsedImg put "
R0lGODlhEAAOAIABAAAAAP///yH5BAEKAAEALAAAAAAQAA4AAAIVjI+py+0fAIBGTmpplDA//13a
SEIFADs=
"
    tablelist_klearlooks_expandedImg put "
R0lGODlhEAAOAIABAAAAAP///yH5BAEKAAEALAAAAAAQAA4AAAIVjI+py+0PEQBntkmxw/bpSEXi
SI4FADs=
"
}

#------------------------------------------------------------------------------
# tablelist::mateTreeImgs
#------------------------------------------------------------------------------
proc tablelist::mateTreeImgs {} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable mate_${mode}Img \
		 [image create photo tablelist_mate_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_mate_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAI5JREFUKFOVzsENQEAQBdApQAEaUIAyFKARVxGJCsRBAdwUgLg4KGx9VnYmMmvj
8JKf2f+TJWPMb+oxRD2GcCCK5MMXDkQLZPLRhwPRATP0kMjSGwc7qmF4cgHqlznYYgkNtLDDCrEc
3F0XeNTBBiOksuy6LtjRBNcgl6U3DnZUyUcfDp6vaNRjiHr8ZugEGr3O4KKrCEAAAAAASUVORK5C
YII=
"
	tablelist_mate_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAI1JREFUKFOV0L0NwjAQhuEbgAG8AAMwgJdhDbr0UFKkygIoKZEiKgYzb5zEnMkp
J4rHsr/7KSwppb+ZoccMPWbomQ+RiPeO42ZoGbyjw0V54KwHcm+5iARMW29o0KLHQQ/k3urBVgy4
4oWo66WverAV0/YnRl3TtsH3U8JvbWWHIicrX5mhxww9ZrgvyQcolMcXU9O+JgAAAABJRU5ErkJg
gg==
"
	tablelist_mate_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAI1JREFUKFOVkMENgzAMRf8WTNEpmIFZOgGDcKsqem3FBSE6ERO4P8SKLWSIenjK
i/MtW4GI/E1YrBEWa5gAjX+4wgRYyd0/nmECbNo4kdaHjpgAXzKSWX0g4comOfggL/LWe5p88w17
tog1fUgKp4mdD5dskdy06Nn70BGTHH6S6tebnKwSERZrhMVrBD8rI88WMxe4BQAAAABJRU5ErkJg
gg==
"
	tablelist_mate_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAH9JREFUKFOVkNENgDAIBZnFSbqHU7hDp3EDExNTHQyh0kotKfHjVI73+BAQ8Tem
9DClhyk9ngdAJK4Bc1eSYiJOYlNwYdWFnK0fAEFCB7ETfITnSRdythnoqgS5yO+o9zXXDHRVwkzS
O00v3p8SvruCLQEWyxdM6WFKD1OOQbgBANvLoUTXnyUAAAAASUVORK5CYII=
"
    } else {
	tablelist_mate_collapsedImg put "
R0lGODlhDQAOAIQTAAAAADw8PEBAQEVFRUdHR0hISElJSVVVVVxcXF1dXWlpaW1tbW9vb319fYCA
gIKCgoSEhI2Njba2tv///////////////////////////////////////////////////yH5BAEK
AB8ALAAAAAANAA4AAAUl4CeOZGmeaJoWkvoFhqIGThJEaAA1jECcusUAkTsMZg+XcqkMAQA7
"
	tablelist_mate_expandedImg put "
R0lGODlhDQAOAIQQAAAAADw8PEJCQkREREdHR09PT1BQUFJSUl9fX2VlZWlpaXFxcXJycn19fYSE
hJ2dnf///////////////////////////////////////////////////////////////yH5BAEK
AAAALAAAAAANAA4AAAUkICCOZGmeaJoGbBuYCuLMx3MGS5MYacEIKgNhoAK8isikEhUCADs=
"
	tablelist_mate_collapsedActImg put "
R0lGODlhDQAOAOMOAAAAADw8PD09PT8/P0FBQUZGRkhISElJSVJSUlNTU1VVVVdXV15eXoiIiP//
/////yH5BAEKAA8ALAAAAAANAA4AAAQg8MlJq704Z9H0C0KhBQkRMFiwIAd4qYZApEMwKl6u5xEA
Ow==
"
	tablelist_mate_expandedActImg put "
R0lGODlhDQAOAOMIAAAAADw8PD09PT4+PkBAQENDQ0ZGRlVVVf//////////////////////////
/////yH5BAEKAAAALAAAAAANAA4AAAQfEMhJq70458B7sINgjMFxBUQxfBjKtsGgAe9s37gVAQA7
"
    }
}

#------------------------------------------------------------------------------
# tablelist::mintTreeImgs
#------------------------------------------------------------------------------
proc tablelist::mintTreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable mint_${mode}Img \
		 [image create photo tablelist_mint_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_mint_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOvwAADr8BOAVTJAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAV0lE
QVQoU2P4//8/yRirICGMymFgmI3Mx4VROQwM94B4MbIYNozKgWi6SkgjKgeiiaBGVA5CEwhfB+Lt
yPJwdSgcCjWR7DyyAoLkICc9conFWAXx4/8MALGp3eTNJauCAAAAAElFTkSuQmCC
"
	tablelist_mint_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOvwAADr8BOAVTJAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAW0lE
QVQoU5WL0Q2AMAgFmcGBuv8EfnYVlLaS1F76lOQ+ODhz99+gVKBUoFSgVMSUm/qBktEoIzzH8U34
DDLahEvQfqdlDjFof4voYUQYBCzNDvIPKBUoFSj3uF1KHMxW02hYDgAAAABJRU5ErkJggg==
"
	tablelist_mint_collapsedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOvgAADr4B6kKxwAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAUUlE
QVQoU2P4//8/yRirICGMLjAPjY8Vowu8AOLlaGIYGF0ApOk+EOPViC4A0kRQI7oATBNM4z4gRldD
XU0kO4+sgCA5yMmKXKIwVkH8+D8DAIioOIlmRAZbAAAAAElFTkSuQmCC
"
	tablelist_mint_expandedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAOCAYAAAD0f5bSAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOvwAADr8BOAVTJAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAWklE
QVQoU5XLsQ2AMBBD0TTsxP6L0LLFYRecQPmKoXiIfJ1HVf2GMcGYYEwwJv7scn7gux7dw0Po2L0H
1j9Cw2lgr4c8hziwKYgPPcKBYZQNWsOYYEwwrtW4AJnXOKReFQYYAAAAAElFTkSuQmCC
"
    } else {
	tablelist_mint_collapsedImg put "
R0lGODlhDQAOAMIHAAAAACEhISgoKCoqKkhISFxcXGRkZP///yH5BAEKAAcALAAAAAANAA4AAAMd
eLrc/sdAFspUYdgZ8n5dIBBQOJYep13VFbkwnAAAOw==
"
	tablelist_mint_expandedImg put "
R0lGODlhDQAOAKEDAAAAACEhISkpKf///yH5BAEKAAMALAAAAAANAA4AAAIWnI+py+0fopRJzCCW
jZnZ3gTPSJZNAQA7
"
	tablelist_mint_collapsedSelImg put "
R0lGODlhDQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAANAA4AAAIXhI+pC8EY3Gtxxsou
Vlry+4Chl03maRQAOw==
"
	tablelist_mint_expandedSelImg put "
R0lGODlhDQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAANAA4AAAIRhI+py+0fopRpUmXb
1a/73xQAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::newWaveTreeImgs
#------------------------------------------------------------------------------
proc tablelist::newWaveTreeImgs {} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable newWave_${mode}Img \
		 [image create photo tablelist_newWave_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_newWave_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuNUmK/OAAAADDSURBVDhPY2AYtMDHx4cPiGf4+vqKUuRI
oCECHh4eH9zd3e8D2YVAzEqWgSCDnJ2db7GxseWbmZlt8vb2vggU8yLZMJBBLi4uV4EaI0BYVFQ0
y9HR8RBQfCsQaxBtIMggNze3i0ANbshYQ0MjH+jdy0D5fpAaggaCFAE1nAEqNEHGOjo6KcCwA3mT
eIM8PT1PAA1RAmFVVVVroAs3k+U1Ly+vw7KyspJAAzqABpwjO7CBGh8DMcgbFEU/dRIkwdiglwIA
fVBDhQiKWqEAAAAASUVORK5CYII=
"
	tablelist_newWave_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuNUmK/OAAAACySURBVDhPY2AY3sDHx4cPiAUIYD6CoQA0
YIaHh8cHJyenu9gwSA6khqBBvr6+okDF99jY2PKBirOQMUgMJAdSQ9AgkAKgjYUWFhargcwIZAwS
A8kRZQjUIFZvb+8LEhIS0UC+GwiD2CAxoEGsRBsENczLxcVlB5BtCsIgNtAQL5IMgSkGatxqYmIS
BsIgNlmGQF2lAfTOKRAGGqRBtkFQw/qBhvRTZAjUIHDipNggcgwAAMDwRMOkXl9fAAAAAElFTkSu
QmCC
"
	tablelist_newWave_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuNUmK/OAAAADOSURBVDhPY2AYtMDExITP2Nh4BhCLUuRI
oEECdqbGf+xNjd8ADSsE8lnJMhBkkI+F8Y9ZHoZP0u2MPlqYGF8HGuhFsmFggyyNvy/yNXoAwlO8
jB6H2xh/ARq2DYg1iDYQZJCvlfG3pYHGd5Fxp5fxEw9L489Aw/qBWICggWCDrI2/rgg1uYmMu3xM
HgEN+kSSQX7WJl/XRJpdA+E5Iaa3Iu1NPpLlNT8bky+rYswv57iZvrAwNb5GdmDbmxv/crQweUVp
9FMnQRKMDXopAACu/llcB/jCVQAAAABJRU5ErkJggg==
"
	tablelist_newWave_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABIAAAAOCAYAAAAi2ky3AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuNUmK/OAAAAC7SURBVDhPY2AY3sDExIQPiAUIYD6CoWBs
bDzD1tT4j7e50U9sGCQHUkOMQaL2psZvZrgaPJvjhopBYiA5oEGiBA0CKQAqLEy3N/qw0MfoITIG
iYHkiDIEpAgYPqwWJsbXpvsaP1gaaHwXhEFskBhIjmiDoK7yirAz+bgq3PQGCIPYQNd4kWQITDFQ
47a+QNO7IGwCZJNlCNRVGp7WJh9AGGioBtkGQQ3rBxrST5EhUIMEgAYJUGwQOQYAAONtWMaau7wh
AAAAAElFTkSuQmCC
"
    } else {
	tablelist_newWave_collapsedImg put "
R0lGODlhEgAOAIQdAAAAAFJSUl5eXl9fX2JiYmZmZmdnZ2lpaWtra2xsbG5ubnBwcHJycnR0dH19
fX9/f5KSkpSUlJqampycnJ2dnaGhoaenp6ysrLm5ucvLy8zMzN3d3ejo6P///////////yH5BAEK
AB8ALAAAAAASAA4AAAU44CeOZGme6BilaCCwpgAxCDwSlkUpj21gQEylIGEhMsjM5VBMLTYbjaMH
a3AmCptokNCqvOBwKQQAOw==
"
	tablelist_newWave_expandedImg put "
R0lGODlhEgAOAIQSAAAAAFJSUltbW19fX2xsbHBwcHh4eHl5eX9/f5KSkpSUlJWVlZqamqenp6ys
rLm5ubq6usrKyv///////////////////////////////////////////////////////yH5BAEK
AB8ALAAAAAASAA4AAAU14CeOZGmeaKqupxIIcBwo6ZAs+JIM69H8jQOL4Hg8HATWxxCJGJQfBASC
gH4KBeuHwdB6oSEAOw==
"
	tablelist_newWave_collapsedActImg put "
R0lGODlhEgAOAKUgAAAAAEA3NUI6N1A9OFE/OVNAOlNCO1BCPFFDPVRCO1VEPF5EO2JJP29IPU1E
QlBIRFdTU1dVU3lWR21tbZVdSJ9dSJdgS6RbRq1iSqpsUrFoTrRuUrlzVrh4WYWFhYyMjP//////
////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////yH5BAEKAAAALAAAAAASAA4AAAY8QIBw
SCwaj8ihJ4kMOJjGwaUBgQ4JGExlMbEWNGAN5fBhGjbojQVRTiY4nAyjC1V0JBGrUPDQK/2AgUVB
ADs=
"
	tablelist_newWave_expandedActImg put "
R0lGODlhEgAOAIQSAAAAAD83NU87NlNGP2FIP29KPk1EQldUU21tbZ1oT6JXRKVYRKNiS6xhSrFo
TrdwU4WFhYyMjP///////////////////////////////////////////////////////yH5BAEK
AB8ALAAAAAASAA4AAAU14CeOZGmeaKquJxQIcBxAqaEs+KIYa9H8jQLrwHA4GAfWh/B4EJQfRCKB
gH4GA+snEtF6oSEAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::oxygen1TreeImgs
#------------------------------------------------------------------------------
proc tablelist::oxygen1TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable oxygen1_${mode}Img \
		 [image create photo tablelist_oxygen1_${mode}Img]
    }

    tablelist_oxygen1_collapsedImg put "
R0lGODlhEAAOAKECAAAAABQTEv///////yH5BAEKAAAALAAAAAAQAA4AAAIShI+py+0PVYhmwoBx
tJv6D0YFADs=
"
    tablelist_oxygen1_expandedImg put "
R0lGODlhEAAOAKECAAAAABQTEv///////yH5BAEKAAAALAAAAAAQAA4AAAIPhI+py+0Po2yh1omz
3rwAADs=
"
}

#------------------------------------------------------------------------------
# tablelist::oxygen2TreeImgs
#------------------------------------------------------------------------------
proc tablelist::oxygen2TreeImgs {} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable oxygen2_${mode}Img \
		 [image create photo tablelist_oxygen2_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_oxygen2_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAAOCAYAAAAmL5yKAAAABGdBTUEAALGPC/xhBQAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuODc7gF0AAABOSURBVDhPY2AYBegh4AIU8KMkWDyBmh8C
cTUlhpgANV8B4gVAzE2uQdZAjc+BuJQcA6yAmq4B8Swg5iDVAG+ghkfk2gyyzBGIQQE5kgAA2mMJ
YLECIngAAAAASUVORK5CYII=
"
	tablelist_oxygen2_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAAOCAYAAAAmL5yKAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuODc7gF0AAABRSURBVDhPY2AYBVQNAUegad5oJnoC+S7E
2gJS/AiIraAaTID0QyD2I9YAkLpSIL4GxNZAfAWIq0nRDFM7C8h4DsQLyNEM0sMBdQk3uQaMNH0A
PvwJYFasmD4AAAAASUVORK5CYII=
"
	tablelist_oxygen2_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAAOCAYAAAAmL5yKAAAABGdBTUEAALGPC/xhBQAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuODc7gF0AAABbSURBVDhPY2AYBSghkHDhvwsQ+5EdLEDN
nkD8EIirKTHEBGjAFSBeAMTcZBkE1GgNxM+BuJRkA4CarID4GhDPAmIOkgwAavAG4kdk2QyyCajR
ERSQJNk69BUDAI0BNzsiLc7tAAAAAElFTkSuQmCC
"
	tablelist_oxygen2_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAAOCAYAAAAmL5yKAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAABl0RVh0
U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuODc7gF0AAABcSURBVDhPY2AYBdQLgYQL/x2B2BvZRCDf
E4hdiLIFqvgRkLYCaQDSJkD8EIj9iDIAqqkUqOEaEFsD8RUgriZaM0whUNMsIH4OxAtI1gx1BQdQ
M8gl3GQZMAI1AQCLtzc7P7D1iQAAAABJRU5ErkJggg==
"
    } else {
	tablelist_oxygen2_collapsedImg put "
R0lGODlhEAAOAIABAAAAAP///yH5BAEKAAEALAAAAAAQAA4AAAIVjI+py+0fAIBGTmpplDA//13a
SEIFADs=
"
	tablelist_oxygen2_expandedImg put "
R0lGODlhEAAOAIABAAAAAP///yH5BAEKAAEALAAAAAAQAA4AAAIVjI+py+0PEQBntkmxw/bpSEXi
SI4FADs=
"
	tablelist_oxygen2_collapsedActImg put "
R0lGODlhEAAOAKECAAAAAGDQ/////////yH5BAEKAAAALAAAAAAQAA4AAAIVhI+py+0PQoBGTmpp
lDA//13aSEIFADs=
"
	tablelist_oxygen2_expandedActImg put "
R0lGODlhEAAOAKECAAAAAGDQ/////////yH5BAEKAAAALAAAAAAQAA4AAAIVhI+py+0PUQhntkmx
w/bpSEXiSI4FADs=
"
    }
}

#------------------------------------------------------------------------------
# tablelist::phaseTreeImgs
#------------------------------------------------------------------------------
proc tablelist::phaseTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable phase_${mode}Img \
		 [image create photo tablelist_phase_${mode}Img]
    }

    tablelist_phase_collapsedImg put "
R0lGODlhEAAOAKECAAAAAMfHx////////yH5BAEKAAAALAAAAAAQAA4AAAIYhI+py63hUoDRTBov
bnovXV0VMI2kiaIFADs=
"
    tablelist_phase_expandedImg put "
R0lGODlhEAAOAKECAAAAAMfHx////////yH5BAEKAAAALAAAAAAQAA4AAAIThI+py+0PT5iUsmob
hpnHD4ZhAQA7
"
}

#------------------------------------------------------------------------------
# tablelist::plain1TreeImgs
#------------------------------------------------------------------------------
proc tablelist::plain1TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable plain1_${mode}Img \
		 [image create photo tablelist_plain1_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_plain1_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAJCAYAAAAGuM1UAAAAMElEQVQY02NgQIB6BiIAExq/nlQN
BDUx4RCvJ1UDTk34NDSSoqGRFCc1MhAJiIoHAPzJBIzdNMy+AAAAAElFTkSuQmCC
"
	tablelist_plain1_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAJCAYAAAAGuM1UAAAALklEQVQY02NgoDVgZGBgqCdCXSOy
BgYCmhrRbWDAo6kRm5MYcGhqJNZf9QwDCgAizASENAzPWgAAAABJRU5ErkJggg==
"
    } else {
	tablelist_plain1_collapsedImg put "
R0lGODlhDAAJAIABAH9/f////yH5BAEKAAEALAAAAAAMAAkAAAISTGCpBrja3Dtx0vqiXHg2y4AF
ADs=
"
	tablelist_plain1_expandedImg put "
R0lGODlhDAAJAIABAH9/f////yH5BAEKAAEALAAAAAAMAAkAAAIPjI+pB+2OHkxyhWmB3RwVADs=
"
    }
}

#------------------------------------------------------------------------------
# tablelist::plain2TreeImgs
#------------------------------------------------------------------------------
proc tablelist::plain2TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable plain2_${mode}Img \
		 [image create photo tablelist_plain2_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_plain2_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA4AAAALCAYAAABPhbxiAAAAOUlEQVQoz2NgQAVNDEQCJixiTeRq
JEozEx65JnI14tXMRIR3msjVWEeOxjpynFpHTuDUMZAIiE45APJdBZkq7zr6AAAAAElFTkSuQmCC
"
	tablelist_plain2_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA4AAAALCAYAAABPhbxiAAAANklEQVQoz2NgoDdgZGBgqCdBfSOy
RgYiNTei28hAhOZGbE5lIKC5EZcfGfBobiQ10OoZhg8AALhPBYVNoXj+AAAAAElFTkSuQmCC
"
    } else {
	tablelist_plain2_collapsedImg put "
R0lGODlhDgALAIABAH9/f////yH5BAEKAAEALAAAAAAOAAsAAAIXjGGpCrjf3EtRzmoXzrTOE30g
p5GaGBQAOw==
"
	tablelist_plain2_expandedImg put "
R0lGODlhDgALAIABAH9/f////yH5BAEKAAEALAAAAAAOAAsAAAITjI+pC+0PEHxqRkaXcVr2D4Za
AQA7
"
    }
}

#------------------------------------------------------------------------------
# tablelist::plain3TreeImgs
#------------------------------------------------------------------------------
proc tablelist::plain3TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable plain3_${mode}Img \
		 [image create photo tablelist_plain3_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_plain3_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABEAAAANCAYAAABPeYUaAAAAQ0lEQVQoz2NgQAX1DGQAJixi9dQw
hGSDmPDI1VPDEKINYiJCTT01DCFoELGGNFJqSCOl3mmkNGAbKY3iRgYKAFl5BwCpnQaUXzVUsAAA
AABJRU5ErkJggg==
"
	tablelist_plain3_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABEAAAANCAYAAABPeYUaAAAAPUlEQVQoz+XRMQ4AIAhD0e/JSW/u
blBAN+nOCxT4KgOwizmtCEVI3iYUIO3OIQnp1AkJSFGxBJBePmf0zAT3jwaGIuX2/gAAAABJRU5E
rkJggg==
"
    } else {
	tablelist_plain3_collapsedImg put "
R0lGODlhEQANAIABAH9/f////yH5BAEKAAEALAAAAAARAA0AAAIcjGGpe8gfgIRMTprsxXrD7lUd
FmlkGX6pemZtAQA7
"
	tablelist_plain3_expandedImg put "
R0lGODlhEQANAIABAH9/f////yH5BAEKAAEALAAAAAARAA0AAAIXjI+py60Ao4xp2mUpyy7Mbmig
N5bmeRQAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::plain4TreeImgs
#------------------------------------------------------------------------------
proc tablelist::plain4TreeImgs {} {
    foreach mode {collapsed expanded} {
	variable plain4_${mode}Img \
		 [image create photo tablelist_plain4_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_plain4_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABcAAAARCAYAAAA2cze9AAAAUklEQVQ4y7WUSQoAMAgDxY+H/Lyn
nkrpopOjygTcIlYpmpSbuEh4i0Ee8iLhJYO8rBMJ/zLIx3qR8CeDH7gpuKm2mBqoqVU0dUSmzr8E
xr7h1ADeYgic3eAtOQAAAABJRU5ErkJggg==
"
	tablelist_plain4_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABcAAAARCAYAAAA2cze9AAAATElEQVQ4y+2UiQ0AIAgDz8lJN3cC
lUdNTOwAPVIK8HVbDbANPhqZUwRoNjkFgFaxkATIkzkJgLwLJQhQpC0EAIpWESdAJ27B/jt4Rx1i
8QiI+CHjPQAAAABJRU5ErkJggg==
"
    } else {
	tablelist_plain4_collapsedImg put "
R0lGODlhFwARAIABAH9/f////yH5BAEKAAEALAAAAAAXABEAAAInjAOnywrZ4npQSlotw1kf3nlg
aI1kZJ7b6H1g62Jw/My0HeOu/ukFADs=
"
	tablelist_plain4_expandedImg put "
R0lGODlhFwARAIABAH9/f////yH5BAEKAAEALAAAAAAXABEAAAIhjI+py+0PYwC02ksX3pnx+3xd
yEkTZhpgqo7s9MbyTCsFADs=
"
    }
}

#------------------------------------------------------------------------------
# tablelist::plastikTreeImgs
#------------------------------------------------------------------------------
proc tablelist::plastikTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable plastik_${mode}Img \
		 [image create photo tablelist_plastik_${mode}Img]
    }

    tablelist_plastik_collapsedImg put "
R0lGODlhDwAOAMIDAAAAAHZ2drW1tf///////////////////yH5BAEKAAQALAAAAAAPAA4AAAMq
SLrc/jASEWoVj469A24BB3CBE25jZw5A2w4lKJIrSjcaB3+4dUnAICMBADs=
"
    tablelist_plastik_expandedImg put "
R0lGODlhDwAOAMIDAAAAAHZ2drW1tf///////////////////yH5BAEKAAQALAAAAAAPAA4AAAMo
SLrc/jASEWoVj469A24BJwZOKHblAKzrQIInCscvo41fQ1me5P+MBAA7
"
}

#------------------------------------------------------------------------------
# tablelist::plastiqueTreeImgs
#------------------------------------------------------------------------------
proc tablelist::plastiqueTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable plastique_${mode}Img \
		 [image create photo tablelist_plastique_${mode}Img]
    }

    tablelist_plastique_collapsedImg put "
R0lGODlhEAAOAOMLAAAAAHp4eH59fa+trfHx8fPz8/X19ff39/n5+fv7+/39/f//////////////
/////yH5BAEKAA8ALAAAAAAQAA4AAAQ+8MlJq704zyG6F8MlKGSpCGKiBmqCWgIiBzLyVsIR7Ptx
UwKDMCA0/CaCgjKgLBwlAoJ0Sng+OJ9OSMPtViIAOw==
"
    tablelist_plastique_expandedImg put "
R0lGODlhEAAOAOMLAAAAAHp4eH59fa+trfHx8fPz8/X19ff39/n5+fv7+/39/f//////////////
/////yH5BAEKAA8ALAAAAAAQAA4AAAQ78MlJq704zyG6F8MlKGSpCGKirglqCUgsI24lHEGeHzUl
GMCgoTcRFI7IAlEiIDifhOWD8+mENNhsJQIAOw==
"
}

#------------------------------------------------------------------------------
# tablelist::radianceTreeImgs
#------------------------------------------------------------------------------
proc tablelist::radianceTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable radiance_${mode}Img \
		 [image create photo tablelist_radiance_${mode}Img]
    }

    tablelist_radiance_collapsedImg put "
R0lGODlhEwAPAKUoAAAAAEBAQOTe1eTe1uTf1+bh2ejj2ujk3erl3uvn4Ozo4u3p4+7q5O/r5u/s
5+/t6PDt6PPw7PLw7fXz8Pb08ff18vb18/f28vj28fj28vj28/j39Pj39fj49fn49/n5+Pr6+Pv7
+fz8+fz8+vz8+/39/P39/f7+/f//////////////////////////////////////////////////
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAaawN/v
ICgajQehUljAjEynaNQ0ohSWQwuJVOp6S1tLUikAgUKikVotCpkFS4Fn/qkH6p+5B07mcDYbHB0B
HX9+HHxCAhoaGRoUFQEVFReMGok/AhQUEwGenwGbFJgCEhESqBIBqamkEA+wsAGxsBCkC7i5Abm4
DKQJCMHCwwgKmAcNBsrLzAYOY0oFCgQD1dYDBApXWENH3tBKQQA7
"
    tablelist_radiance_expandedImg put "
R0lGODlhEwAPAKUoAAAAAEBAQOTe1eTe1uTf1+bh2ejj2ujk3erl3uvn4Ozo4u3p4+7q5O/r5u/s
5+/t6PDt6PPw7PLw7fXz8Pb08ff18vb18/f28vj28fj28vj28/j39Pj39fj49fn49/n5+Pr6+Pv7
+fz8+fz8+vz8+/39/P39/f7+/f//////////////////////////////////////////////////
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAATAA8AAAaUwN/v
ICgajQehUljAjEynaNQ0ohSWQwuJVOp6S1tLUikAgUKikVotCpkFS4Fn/qnbP3MPnMzhbDYcHYJ+
fRx7QgIaGhkaFBUXFY+KGoc/AhQUEwGbnAGYFJUCEhESpaanEqEQD6ytrg8QoQuztLWzDKEJCLu8
vQgKlQcNBsTFxgYOY0oFCgQDz9ADBApXWENH2MpKQQA7
"
}

#------------------------------------------------------------------------------
# tablelist::ubuntuTreeImgs
#------------------------------------------------------------------------------
proc tablelist::ubuntuTreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable ubuntu_${mode}Img \
		 [image create photo tablelist_ubuntu_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_ubuntu_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAeUlE
QVQoU5XRTQ5AMBAF4HcJCXEp4lIssLXFQmLlhuONn+gIVYtv8TovbdNCRII9Lr6xAYjdfGcDMFPm
rrlsABYaqaXUnW1zE/ZySR3pKYWZm3CVVUMD6SnJV1lVNB0iX1l37qkm787nnXMzN2EvB7/Gr3cO
/0E/wQq/q1nj7KhNMQAAAABJRU5ErkJggg==
"
	tablelist_ubuntu_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAi0lE
QVQoU43QQQ5AMBAF0LmDFXEN1xDO0YuwwdYWiaSJlQPWn6IpnQrJi/T3N1PIGPObGMaIYYwYxvCT
gob9wwb5faKEBRrBDLXteSMGGMEv8npwHa+cwQo9cJHfWilVBOXrAF9nghZ4fPXY9xc2IOqAJ7jx
bi8Izr/DH5sHe+/AhkSJmEthjBjKDB0QEltZUh1wpAAAAABJRU5ErkJggg==
"
	tablelist_ubuntu_collapsedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAh0lE
QVQoU43QMQrDMAyF4VykkCFbT9H7ZAm5X+gQKKV7IBcIgUzp2EX9Ba6xFDfY8A16FpJxJSLFsuE/
Pri62vDBG73LIh98sOCFwxZTQM8dM3aYLWmj0slD8IBueaLBafPPhhWXs+YRRZMn6Js7xPu0UaW/
UYcsMgV0WuuyyAc3VxvZME+qL4Ax7PyHSW8ZAAAAAElFTkSuQmCC
"
	tablelist_ubuntu_expandedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAhUlE
QVQoU43OMQqAMBAEwDzB1kKw8GMi+DfBQgQ/YC9YiGDvP85dMeGCF7EYw21Osk5EfjPDFDNMMcMU
fkrY4fxwQOX/amCB3sC8hajGBDN0Cmfm945eLmCDEbjIk/VY87VMNfg6PFkv3OtFbwC+EJ73ouGR
wwqsFd1Fg5IZWXLZZIY2cRe5CulmXcWbqAAAAABJRU5ErkJggg==
"
    } else {
	tablelist_ubuntu_collapsedImg put "
R0lGODlhCwAOAKECAAAAAExMTP///////yH5BAEKAAAALAAAAAALAA4AAAIWhI+py8EWYotOUZou
PrrynUmL95RLAQA7
"
	tablelist_ubuntu_expandedImg put "
R0lGODlhCwAOAKECAAAAAExMTP///////yH5BAEKAAAALAAAAAALAA4AAAIThI+pyx0P4Yly0pDo
qor3BoZMAQA7
"
	tablelist_ubuntu_collapsedSelImg put "
R0lGODlhCwAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAALAA4AAAIWhI+py8EWYotOUZou
PrrynUmL95RLAQA7
"
	tablelist_ubuntu_expandedSelImg put "
R0lGODlhCwAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAALAA4AAAIThI+pyx0P4Yly0pDo
qor3BoZMAQA7
"
    }
}

#------------------------------------------------------------------------------
# tablelist::ubuntu2TreeImgs
#------------------------------------------------------------------------------
proc tablelist::ubuntu2TreeImgs {} {
    foreach mode {collapsed expanded collapsedSel expandedSel} {
	variable ubuntu2_${mode}Img \
		 [image create photo tablelist_ubuntu2_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_ubuntu2_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAkAAAAOCAYAAAD9lDaoAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAE1JREFUKFNj+P//P0GMVRAdYxVEx6gcBoYqZD5cHIXDwPARiC2QxcDiKBwGhsNA
vA9dITZFGArJVkSUdQQdTjgIcGGsgugYqyAq/s8AANujSFT6BI1/AAAAAElFTkSuQmCC
"
	tablelist_ubuntu2_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAkAAAAOCAYAAAD9lDaoAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAFRJREFUKFOFzLENwCAQQ1HPTZGahWjTZLDjgOgAxyjFQ+JjATP7JSOTkcnIZGTj
AJJ7DtJcA5cr70Nzuxw/iWEMPqMexjAGva2XExmZjExGJuPOUAFkYUnWqebyBwAAAABJRU5ErkJg
gg==
"
	tablelist_ubuntu2_collapsedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAAkAAAAOCAYAAAD9lDaoAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAFBJREFUKFNj+P//P0GMVRAdYxVEx6gcBgZxZD5cHIXDwKACxDzIYmBxFA5QEZC2
QleITREIoCgkWxFh69AVgMVROMQEAS6MVRAdYxVExf8ZAH0VUvQp9pDFAAAAAElFTkSuQmCC
"
	tablelist_ubuntu2_expandedSelImg put "
iVBORw0KGgoAAAANSUhEUgAAAAkAAAAOCAYAAAD9lDaoAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAFlJREFUKFOFzdEJwCAUQ9H8C/1ygW7QAbr/Ws+gaJ8h0sKp7SUgIuKXjcpGZaOy
UY0XUOk+qN8auHg+NJ+XrfDcr0vDNeh9fqzAYR70ln9ObFQ2KhuVjbtAAynEUs/p9GxtAAAAAElF
TkSuQmCC
"
    } else {
	tablelist_ubuntu2_collapsedImg put "
R0lGODlhCQAOAMIEAAAAAA4ODjw8PEFBQf///////////////yH5BAEKAAEALAAAAAAJAA4AAAMR
GLrc/nAJKMYT1WHbso5gGCYAOw==
"
	tablelist_ubuntu2_expandedImg put "
R0lGODlhCQAOAMIEAAAAADw8PEFBQUpKSv///////////////yH5BAEKAAAALAAAAAAJAA4AAAMR
CLrc/jCqQCsbVLihpf+glAAAOw==
"
	tablelist_ubuntu2_collapsedSelImg put "
R0lGODlhCQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAAJAA4AAAIOhI+py43BAlRyTYez
BgUAOw==
"
	tablelist_ubuntu2_expandedSelImg put "
R0lGODlhCQAOAKEBAAAAAP///////////yH5BAEKAAAALAAAAAAJAA4AAAINhI+py+0WYlDx2YtX
AQA7
"
    }
}

#------------------------------------------------------------------------------
# tablelist::vistaAeroTreeImgs
#------------------------------------------------------------------------------
proc tablelist::vistaAeroTreeImgs {{treeStyle "vistaAero"}} {
    variable scaling
    vistaAeroTreeImgs_$scaling $treeStyle
}

#------------------------------------------------------------------------------
# tablelist::vistaAeroTreeImgs_100
#------------------------------------------------------------------------------
proc tablelist::vistaAeroTreeImgs_100 {{treeStyle "vistaAero"}} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_${treeStyle}_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAOCAYAAAAWo42rAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAXElE
QVQoU2MYeGAJxNwQJn4QAcThQCwM5uEBIIWiQJwCxNIgAVwg4v///yAaZGI+EKuCONgAWCFUsQQQ
1wKxIIiDDmAmCgExfhOBWASICbsRiInyNdHhSC3AwAAAOscS06dRs0kAAAAASUVORK5CYII=
"
	tablelist_${treeStyle}_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAOCAYAAAAWo42rAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAOklE
QVQoU2MYosARiMshTNwApOgKEN8E83AAsKKIiIj/QBqnQrgifApRFOFTCHI4SAIZVwLxEAMMDABG
vRjvyt4dygAAAABJRU5ErkJggg==
"
	tablelist_${treeStyle}_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAOCAYAAAAWo42rAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAX0lE
QVQoU2MYYCBz5PsUIDaEcnEDoKJPQHwdiJ2hQtgBVGEBEL8E4kioMCYAKfz//z+ITgLibyAaKoUK
YAqhitOB+D8Qa0ClEQCmEEgTNhGIiXMjEBPla+LCkYqAgQEAADRV6Wfd6ZMAAAAASUVORK5CYII=
"
	tablelist_${treeStyle}_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAOCAYAAAAWo42rAAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwwAADsMBx2+oZAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAO0lE
QVQoU2MYikDmyPdKIN4I5WIHUEW/gfg/VAgTwBQ13f/9H6dCZEU4FaIrwqdwI0gCDeP3zKAEDAwA
ThBJQ3HSXa8AAAAASUVORK5CYII=
"
    } else {
	tablelist_${treeStyle}_collapsedImg put "
R0lGODlhCgAOAMIGAIKCgpCQkJubm6enp6ioqMbGxv///////yH5BAEKAAcALAAAAAAKAA4AAAMa
eLrc/qvAMwgcRzx8guMH0HDemG3WI00slAAAOw==
"
	tablelist_${treeStyle}_expandedImg put "
R0lGODlhCgAOAMIFACYmJisrK1hYWIaGhoiIiP///////////yH5BAEKAAcALAAAAAAKAA4AAAMY
eLrc/jASGMALwjact/iaQgAkMERoqioJADs=
"
	tablelist_${treeStyle}_collapsedActImg put "
R0lGODlhCgAOAMIFABzE9ybG9y/J9z/N+Hvc+v///////////yH5BAEKAAcALAAAAAAKAA4AAAMa
eLrc/ovAEwYMRzxMHT9Aw30LpnnWI00slAAAOw==
"
	tablelist_${treeStyle}_expandedActImg put "
R0lGODlhCgAOAKEDAB3E92HW+YLf+////yH5BAEKAAMALAAAAAAKAA4AAAIWnI+pyx0MwAJCJlqv    
2NaEGD3NSJZDAQA7
"
    }
}

#------------------------------------------------------------------------------
# tablelist::vistaAeroTreeImgs_125
#------------------------------------------------------------------------------
proc tablelist::vistaAeroTreeImgs_125 {{treeStyle "vistaAero"}} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_${treeStyle}_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAQCAYAAADNo/U5AAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwgAADsIBFShKgAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAfUlE
QVQ4T6XSQQ5AQAwF0N5gEkMcwM4RnMTW3tLa1euHjjaTIg3Jiz/tNGIgZg5zi1/c4hcNRBMk23yi
gWgWnd3g0XANZFigt5tqGjAk9wZWGEqvpkGGJCfYYCw1S4MZknULO2RbP3t3+PMkXLF3gvjpidB3
iv8REW7xHdMB2BwE/GLft6oAAAAASUVORK5CYII=
"
	tablelist_${treeStyle}_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAQCAYAAADNo/U5AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAFxJREFUOE+Vi8ENwCAMxFiFhfhnFAbsEEyTJmofFTVcG8mP+OTi7r9BqUCpQKlA
mcTVoOGG8gqOYOD+EndgZvno6Bl8iuZARhRso1Wgopbjgo4RSQVKBUoFyj1eTmDxHIxhnZRtAAAA
AElFTkSuQmCC
"
	tablelist_${treeStyle}_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAQCAYAAADNo/U5AAAABGdBTUEAALGPC/xhBQAAAAlwSFlz
AAAOwgAADsIBFShKgAAAABp0RVh0U29mdHdhcmUAUGFpbnQuTkVUIHYzLjUuMTAw9HKhAAAAiklE
QVQ4T2P4//8/yRirICGMVZAQhjNkjnyfAsSGyJK4MJwB1PAEiO8DsTOyAmwYzoBqygbil0AciawI
HcMZIE1QOgmIvwFxAUwOHcMZME1QdqT8ke//gXQbTAwZwxnImqD8QCAGaUxCFgdhZEXk2wQyGYiJ
9xMQkx56QExyPJGeIkjBWAXx4/8MANSdWjtt4ktkAAAAAElFTkSuQmCC
"
	tablelist_${treeStyle}_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAQCAYAAADNo/U5AAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAGNJREFUOE+VkLENgDAMBDMIUzESG2UH9mCDtBQUjy2BhOJP3hRX+F7XuAD4DZUK
KhVUKqh0lv1cjcq2IJwnaIadcQ/iDbbjQir6BqmoD2TEgmk0ClRUfRyQf7mCSgWVCirnoNxb6Wji
ROY2iAAAAABJRU5ErkJggg==
"
    } else {
	tablelist_${treeStyle}_collapsedImg put "
R0lGODlhDQAQAMIGAIGBgYuLi5OTk56enqenp8XFxf///////yH5BAEKAAcALAAAAAANABAAAAMg
eLrc/rCVuAih5w56j4jdEUDhATzhiCofeWxg+UxYXScAOw==
"
	tablelist_${treeStyle}_expandedImg put "
R0lGODlhDQAQAMIFACYmJjo6OllZWYaGhrGxsf///////////yH5BAEKAAcALAAAAAANABAAAAMd
eLrc/jBKRmYAMggM9e5CyDWe6JQmBazsML1w/CQAOw==
"
	tablelist_${treeStyle}_collapsedActImg put "
R0lGODlhDQAQAMIGAB7E9yTG9y/J9zTK9zjL+Hvc+v///////yH5BAEKAAcALAAAAAANABAAAAMg
eLrc/rCVuAahZxxB9QmRdwCQOD4iiSpguXUXNWE0nQAAOw==
"
	tablelist_${treeStyle}_expandedActImg put "
R0lGODlhDQAQAMIEABzE9yvH92HW+YLf+////////////////yH5BAEKAAQALAAAAAANABAAAAMd
SLrc/jBKJmYAMgwM9e5DyDWe6JQmBaxsNb1w7CQAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::vistaAeroTreeImgs_150
#------------------------------------------------------------------------------
proc tablelist::vistaAeroTreeImgs_150 {{treeStyle "vistaAero"}} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_${treeStyle}_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAASCAYAAABSO15qAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAJFJREFUOE+t0z0OgCAMBeDObv4kDi4mXsN7uLk6urh4enzEkjYEUUCSLz4LNEaR
jDFFgsUUwWIKCUQz1HryCwlEC+v0gjcS7s0NrNDrRTES0ICvLWwwuLkYCdyAs22yw+hqTySoBnxv
mxww6bpPgteAaxOcUPlzjoQ/nwAj/x1g5H8FKDsHLPsklv0LuYLF7wxdltvd7KsuZmUAAAAASUVO
RK5CYII=
"
	tablelist_${treeStyle}_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAASCAYAAABSO15qAAAAAXNSR0IArs4c6QAAAARnQU1BAACx    
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41    
LjEwMPRyoQAAAGlJREFUOE+ljNEJwCAMBd2uMziJdM/+dJo0AQOlnJJHhfvw9F4zs1+gVECpgFIB    
pQLKxM/hDHpLUAYzvpyb3hOWM+69x0UbeMfywDeWBiguD6zi0sAuDioDIz5tOClMUCqgVECpgLKO    
tQe/Jv55neNSLAAAAABJRU5ErkJggg==
"
	tablelist_${treeStyle}_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAASCAYAAABSO15qAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAJJJREFUOE+lk7sNgDAMRDMIy7ACLSUNJduwEPNQUEBpbMk+WVEI+RRPPs65ExIh
EFEXSbOGpFkDxHA8OzP5ZQkQHL6Yk5n9gT8gtGDVufhDOSAkqFNKbpm2ywFhBaqtZDPvCwhfoM9F
JRBxgXpSQswY7wyIuEDDbW9QGhYgrMCF67+ChtvvAdN1E/v+hVaSZjkUXqcxRqqFYZhwAAAAAElF
TkSuQmCC
"
	tablelist_${treeStyle}_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABAAAAASCAYAAABSO15qAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41
LjEwMPRyoQAAAHBJREFUOE+lkrENgCAUBRnEIe3t3IgdXMM4hgXFFxJ+YsxJ/tPiCg7uVSQz+wVK
BZQKKBVQKqB0pu2cK5nuHJSNHpdKPfKbBkqPl72YPHCP10MceMbSAMXhgbc4NDCKowO5PRrw7R9E
QamAUgFlHEsXE7ZZ8M/FGe4AAAAASUVORK5CYII=
"
    } else {
	tablelist_${treeStyle}_collapsedImg put "
R0lGODlhEAASAMIHAIaGhouLi5CQkJiYmKGhoaioqMPDw////yH5BAEKAAcALAAAAAAQABIAAAMo
eLrc/jA2I1spdWGSDz5D9h1CNR6BdB5AdKbuUqpKaB6cuEZU5/+KBAA7
"
	tablelist_${treeStyle}_expandedImg put "
R0lGODlhEAASAMIFACYmJisrK1lZWYaGhoiIiP///////////yH5BAEKAAcALAAAAAAQABIAAAMj
eLrc/jDKSSWpJ4AaxJ6dBwrkB4VlhKbPyjYEIM/AgN14HiUAOw==
"
	tablelist_${treeStyle}_collapsedActImg put "
R0lGODlhEAASAMIEABzE9ybG9yvH93jc+v///////////////yH5BAEKAAQALAAAAAAQABIAAAMj
SLrc/jC2IVsQdQWyc+8SCELj6JhAVIZa9XlcxmEyJd+4kgAAOw==
"
	tablelist_${treeStyle}_expandedActImg put "
R0lGODlhEAASAMIEAB3E92HW+Xvd+4Lf+////////////////yH5BAEKAAQALAAAAAAQABIAAAMj
SLrc/jDKSWWoBIAKxJ7d8EWhKJUmhKbOyjKBJmsXZt84lAAAOw==
"
    }
}

#------------------------------------------------------------------------------
# tablelist::vistaAeroTreeImgs_200
#------------------------------------------------------------------------------
proc tablelist::vistaAeroTreeImgs_200 {{treeStyle "vistaAero"}} {
    foreach mode {collapsed expanded collapsedAct expandedAct} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    variable pngSupported
    if {$pngSupported} {
	tablelist_${treeStyle}_collapsedImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAASCAYAAAC0EpUuAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAA7CAAAOwgEVKEqAAAAAB3RJTUUH3wgQFRY5FqVEQAAAALdJREFUOMvV1K0KwmAYxfH/kSWb
H2BYEbwNqwYtCsPk5ZlkoEWL12G3LAh+NOuxLMhAYdu74HMBP56Hc95Xtgk9LRqYZlFJY0md0JvG
wFRSP/T5J2AmaRAMtf0ADsBCUhwsKNt3IAUSScNg6efwJodHwSqVwztgJakdBJXUA5bA1varDBr9
ANdAavtS9vzoC5jkYFYlqKgAdoE5sLd9rVqp4qYT4Gj7Vqf8n2gGnG0/6z5T/c1/+gY0ATqnOGYP
YwAAAABJRU5ErkJggg==
"
	tablelist_${treeStyle}_expandedImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAASCAYAAAC0EpUuAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAA7CAAAOwgEVKEqAAAAAB3RJTUUH3wgQFR4HHx3T4wAAAHBJREFUOMvt1LENgDAMRNHvrMMg
mcEtS2QEKnZgKBqmOTokpCRSkOlykjv7SXZhk0R0Ej9kou2YWTazMqxKqhaQgRO4Wj3N2R7o7vqC
ptrKwO7uS8hNI8AXGgU+aCQIkKJBAAMKsHZ6DknbEDq/VHhu7UOEowK6r/0AAAAASUVORK5CYII=
"
	tablelist_${treeStyle}_collapsedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAASCAYAAAC0EpUuAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAA7CAAAOwgEVKEqAAAAAB3RJTUUH3wgQFRUhLuSP1QAAALtJREFUOMvV1K0NwkAUwPF/CeKW
eJOcYgVsJQZDAhWIDoBAFBIECJC1LIBAvUluA9QJkmKO5Awk9K6CN8Av77vouo7cMWKAGBYV9UdR
P82daQmcRX2Zu/waOIr6WTbUWXMC1sBB1M+zDSrAFdCI+mW26Ufwpg/8caUieCfqJ1nQ0NMGWDlr
7sloBNbOmv2v5Y+/gFVoAUloALfAwllz6btSxftLifoH8Axgm7L8caYtcHPWXFPPtPibf/oC+/ZF
dwnBIdcAAAAASUVORK5CYII=
"
	tablelist_${treeStyle}_expandedActImg put "
iVBORw0KGgoAAAANSUhEUgAAABUAAAASCAYAAAC0EpUuAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAA7CAAAOwgEVKEqAAAAAB3RJTUUH3wgQFRsSD7fDTQAAAGlJREFUOMtj/P//PwO1ARMDDcCo
obiB7NEfBbJHf2wk1VAWfAYyMDB041NDkkthBsZLsrBQxfvIBrIzUSFMqWEgiqHUMhBuKDUNZGBg
YGCitoGwJOXIwMDAsvD5H1xqNpFqKONoKUV1AADf1CV1ABcRswAAAABJRU5ErkJggg==
"
    } else {
	tablelist_${treeStyle}_collapsedImg put "
R0lGODlhFQASAMIHAIaGhouLi5CQkJiYmKGhoaioqMPDw////yH5BAEKAAcALAAAAAAVABIAAAMs
eLrc/jBKaWYsxb5MdMvH4C3gIYxHeQSjegCeysbL2SoiyqEKxiuVn3CoSAAAOw==
"
	tablelist_${treeStyle}_expandedImg put "
R0lGODlhFQASAMIFACYmJisrK1lZWYaGhoiIiP///////////yH5BAEKAAcALAAAAAAVABIAAAMm
eLrc/jDKSauF5LIAtApCp4HhKJxiRaLWylLuKxFAbQODp+98fyQAOw==
"
	tablelist_${treeStyle}_collapsedActImg put "
R0lGODlhFQASAMIEABzE9ybG9yvH93jc+v///////////////yH5BAEKAAQALAAAAAAVABIAAAMm
SLrc/jBKOWYMwr5AuGae93WLqJnmlAIfOoqpqsQyrWbjUuV8DyUAOw==
"
	tablelist_${treeStyle}_expandedActImg put "
R0lGODlhFQASAMIEAB3E92HW+Xvd+4Lf+////////////////yH5BAEKAAQALAAAAAAVABIAAAMl
SLrc/jDKSauF4TIAtAJCp4GDaJHlhabVyk7uGwVczWVeru98AgA7
"
    }
}

#------------------------------------------------------------------------------
# tablelist::vistaClassicTreeImgs
#------------------------------------------------------------------------------
proc tablelist::vistaClassicTreeImgs {{treeStyle "vistaClassic"}} {
    variable scaling
    vistaClassicTreeImgs_$scaling $treeStyle
}

#------------------------------------------------------------------------------
# tablelist::vistaClassicTreeImgs_100
#------------------------------------------------------------------------------
proc tablelist::vistaClassicTreeImgs_100 {{treeStyle "vistaClassic"}} {
    foreach mode {collapsed expanded} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    tablelist_${treeStyle}_collapsedImg put "
R0lGODlhDAAOAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAMAA4AAAIjnI+py+H/ThC0iiAr
qNhMulHdMAGmeWUgpwph6lmsB0HMjRcAOw==
"
    tablelist_${treeStyle}_expandedImg put "
R0lGODlhDAAOAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAMAA4AAAIgnI+py+H/ThC0iiBt
xWbqmwGiCHZfOXgal54sBDPyXAAAOw==
"
}

#------------------------------------------------------------------------------
# tablelist::vistaClassicTreeImgs_125
#------------------------------------------------------------------------------
proc tablelist::vistaClassicTreeImgs_125 {{treeStyle "vistaClassic"}} {
    foreach mode {collapsed expanded} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    tablelist_${treeStyle}_collapsedImg put "
R0lGODlhDwAQAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAPABAAAAItnI+pyx0PY0BB2Hvn
qRdgbXCWl1EYaYFDBbSup4oCKsTnZ3b4hvWxJGkIh4gCADs=
"
    tablelist_${treeStyle}_expandedImg put "
R0lGODlhDwAQAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAPABAAAAIonI+pyx0PY0BB2Hvn
qRhrw3XWN4QiWQHqCgiomFHwKM+vTUlSw/dIAQA7
"
}

#------------------------------------------------------------------------------
# tablelist::vistaClassicTreeImgs_150
#------------------------------------------------------------------------------
proc tablelist::vistaClassicTreeImgs_150 {{treeStyle "vistaClassic"}} {
    foreach mode {collapsed expanded} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    tablelist_${treeStyle}_collapsedImg put "
R0lGODlhEgASAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAASABIAAAI4nI+py90Bo4wpiIuz
CFUDzSFW9mXhMWIldhrptV7tYAH2fW8dCe5qL/IAUUKTT8OqTJYzh/N5KAAAOw==
"
    tablelist_${treeStyle}_expandedImg put "
R0lGODlhEgASAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAASABIAAAIynI+py90Bo4wpiIuz
CFV7jlheBh7ieJXGiaqDBcSyvHVoat8uO+43HvrVQpOiy4FMHgoAOw==
"
}

#------------------------------------------------------------------------------
# tablelist::vistaClassicTreeImgs_200
#------------------------------------------------------------------------------
proc tablelist::vistaClassicTreeImgs_200 {{treeStyle "vistaClassic"}} {
    foreach mode {collapsed expanded} {
	variable ${treeStyle}_${mode}Img \
		 [image create photo tablelist_${treeStyle}_${mode}Img]
    }

    tablelist_${treeStyle}_collapsedImg put "
R0lGODlhFwASAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAXABIAAAJHnI+pFu0Pmwqi2ovD
xPzqRGHAyH1IeI1AuYlk1qav16q2XZlHePd53cMJdAyOigUyAlawpItJc8qgFuIA1Wmesh1r5PtQ
FAAAOw==
"
    tablelist_${treeStyle}_expandedImg put "
R0lGODlhFwASAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAXABIAAAI+nI+pFu0Pmwqi2ovD
xPzqRHXdh4Ritp0oqK5lBcTyDFTkEdK6neo0z2pZbgzhMGUkDkxCJbPlNAJLkapDUQAAOw==
"
}

#------------------------------------------------------------------------------
# tablelist::winnativeTreeImgs
#------------------------------------------------------------------------------
proc tablelist::winnativeTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable winnative_${mode}Img \
		 [image create photo tablelist_winnative_${mode}Img]
    }

    tablelist_winnative_collapsedImg put "
R0lGODlhDwAOAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAPAA4AAAIlnI+pyx0PoQqiWhGm
BTYnWnGVh1DAeWJa2K2CqH5X+0VRg+dKAQA7
"
    tablelist_winnative_expandedImg put "
R0lGODlhDwAOAKECAAAAAICAgP///////yH5BAEKAAMALAAAAAAPAA4AAAIinI+pyx0PoQqiWhHm
tTnRjWnAOIYeaCLf1qloe0RyQ9dKAQA7
"
}

#------------------------------------------------------------------------------
# tablelist::win7AeroTreeImgs
#------------------------------------------------------------------------------
proc tablelist::win7AeroTreeImgs {} {
    vistaAeroTreeImgs "win7Aero"
}

#------------------------------------------------------------------------------
# tablelist::win7ClassicTreeImgs
#------------------------------------------------------------------------------
proc tablelist::win7ClassicTreeImgs {} {
    vistaClassicTreeImgs "win7Classic"
}

#------------------------------------------------------------------------------
# tablelist::winxpBlueTreeImgs
#------------------------------------------------------------------------------
proc tablelist::winxpBlueTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable winxpBlue_${mode}Img \
		 [image create photo tablelist_winxpBlue_${mode}Img]
    }

    tablelist_winxpBlue_collapsedImg put "
R0lGODlhDwAOAIQeAAAAAHiYtbDC08C3psG4p8K4qMO6qsa+rs/Iu9LMv9LMwNbRxtjTydvWzNzY
z9/b0uPg2eTh2eXh2urp4+3t5/Hw6/Dw7PLy7vX18ff28/b29Pf39fz8+vz8+////////yH5BAEK
AB8ALAAAAAAPAA4AAAVJ4CeOZGmeaCoEbBsIZuDNtBfEXQ50XHaXgc1GA9BUJD9SAANoNh/JUeBi
oQAmkEZUFIg4GICFArH9BBKHAoEwMJRXLhYsRa+XQgA7
"
    tablelist_winxpBlue_expandedImg put "
R0lGODlhDwAOAKUgAAAAAHiYtbDC08C3psG4p8K4qMO6qsa+rs/Iu9LMv9LMwNbRxtfSx9jTydvW
zNzYz9/b0uPg2eTh2eXh2urp4+zr5u3t5/Hw6/Dw7PLy7vX18ff28/b29Pf39fz8+vz8+///////
////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////yH5BAEKAD8ALAAAAAAPAA4AAAZOwJ9w
SCwaj8ikIMBsBgTGAGhKBQWin2zWs7kWA50OZ3yZeIkBDWC9hpyHgQzGUqFEHG9hQPJoMBYKCHk/
AQkHBQQEAwaDS05MUEmSk0VBADs=
"
}

#------------------------------------------------------------------------------
# tablelist::winxpOliveTreeImgs
#------------------------------------------------------------------------------
proc tablelist::winxpOliveTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable winxpOlive_${mode}Img \
		 [image create photo tablelist_winxpOlive_${mode}Img]
    }

    tablelist_winxpOlive_collapsedImg put "
R0lGODlhDwAOAIQdAAAAAI6ZfcC3psG4p8K4qMO6qsa+rs/Iu9LMv9LMwNbRxtjTydvWzNzYz9/b
0uPg2eTh2eXh2urp4+3t5/Hw6/Dw7PLy7vX18ff28/b29Pf39fz8+vz8+////////////yH5BAEK
AB8ALAAAAAAPAA4AAAVH4CeOZGmeaPoFbBucQSfP3VsGXA5wG2aTAY0mA8hQIr9R4AJoNh1JUcBS
mQAkD0Z0BWksAIrEYRtAGAiDgaCwXblYqricFAIAOw==
"
    tablelist_winxpOlive_expandedImg put "
R0lGODlhDwAOAKUfAAAAAI6ZfcC3psG4p8K4qMO6qsa+rs/Iu9LMv9LMwNbRxtfSx9jTydvWzNzY
z9/b0uPg2eTh2eXh2urp4+zr5u3t5/Hw6/Dw7PLy7vX18ff28/b29Pf39fz8+vz8+///////////
////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////yH5BAEKACAALAAAAAAPAA4AAAZLQJBw
SCwaj8gkKMBsBo6Bj3T6eRYDnmy2o7ESAxzOZmyReIeBDGC9fpyFAcylQplAGu9lxMFYKBIHeQEI
BgQDAwIFeUtOTEqPkERBADs=
"
}

#------------------------------------------------------------------------------
# tablelist::winxpSilverTreeImgs
#------------------------------------------------------------------------------
proc tablelist::winxpSilverTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable winxpSilver_${mode}Img \
		 [image create photo tablelist_winxpSilver_${mode}Img]
    }

    tablelist_winxpSilver_collapsedImg put "
R0lGODlhDwAOAIQXAAAAAJSVosTO2MXP2cbO2svT3NPZ4tXb5Nnf5trg593i6d/l6uDm6+bq7ufr
7+zv8+/y9PLz9vT39/b3+ff4+vn6+v39/f///////////////////////////////////yH5BAEK
AB8ALAAAAAAPAA4AAAVF4CeOZGmeaPoFbBucwSXP11sGVg7klE0GlQoFQIk4fKPABMBkMpCigCQC
ATwaCuiqsUgAEAeDNnAoDM4CgnblYqnecFIIADs=
"
    tablelist_winxpSilver_expandedImg put "
R0lGODlhDwAOAIQYAAAAAJSVosTO2MXP2cbO2svT3NPZ4tXb5Nnf5trg593i6d/l6uDm6+bq7ufr
7+zv8+/x8+/y9PLz9vT39/b3+ff4+vn6+v39/f///////////////////////////////yH5BAEK
AB8ALAAAAAAPAA4AAAVD4CeOZGmeaPoFbBucASbP2FsGV65XNhlYlopQ4uiNAhSAUskwigITSQTy
aCicq8YikUAcDNjAoTAoCwjYlYulartJIQA7
"
}

#------------------------------------------------------------------------------
# tablelist::yuyoTreeImgs
#------------------------------------------------------------------------------
proc tablelist::yuyoTreeImgs {} {
    foreach mode {collapsed expanded} {
	variable yuyo_${mode}Img \
		 [image create photo tablelist_yuyo_${mode}Img]
    }

    tablelist_yuyo_collapsedImg put "
R0lGODlhDwAOAOMKAAAAAIiKhby9ur7AvMDBvsrMyd3e3eHi4OHi4f7+/v//////////////////
/////yH5BAEKAA8ALAAAAAAPAA4AAARA8MlJq72zjM1HqQWSKCSZIN80jORRJgM1lEpAxyptl7g0
E4Fg0KDoPWalHcmIJCmLMpZC8DKGpCYUqMNJYb6PCAA7
"
    tablelist_yuyo_expandedImg put "
R0lGODlhDwAOAOMIAAAAAIiKhb7AvMDBvsrMyd3e3eHi4f7+/v//////////////////////////
/////yH5BAEKAA8ALAAAAAAPAA4AAAQ58MlJq72TiM0FqYRxICR5GN8kjGV5CJTQzrA6t7UkD0Hf
F4jcQ3YjCYnFI2v2ooSWJhSow0lhro8IADs=
"
}

#------------------------------------------------------------------------------
# tablelist::createTreeImgs
#------------------------------------------------------------------------------
proc tablelist::createTreeImgs {treeStyle depth} {
    set baseWidth  [image width  tablelist_${treeStyle}_collapsedImg]
    set baseHeight [image height tablelist_${treeStyle}_collapsedImg]

    #
    # Get the width of the images to create for the specified depth and
    # the destination x coordinate for copying the base images into them
    #
    set width [expr {$depth * $baseWidth}]
    set x [expr {($depth - 1) * $baseWidth}]
    if {[regexp {^(vistaAero|win7Aero)$} $treeStyle]} {
	variable scaling
	switch $scaling {
	    100 { set factor  0 }
	    125 { set factor -3 }
	    150 { set factor -6 }
	    200 { set factor -11 }
	}
    } elseif {[regexp {^(vistaClassic|win7Classic)$} $treeStyle]} {
	variable scaling
	switch $scaling {
	    100 { set factor -2 }
	    125 { set factor -5 }
	    150 { set factor -8 }
	    200 { set factor -13 }
	}
    } elseif {[regexp {^(mate|ubuntu)$} $treeStyle]} {
	set factor -2
    } elseif {[regexp \
	    {^(baghira|klearlooks|oxygen.|phase|plasti.+|winnative|winxp.+)$} \
	    $treeStyle]} {
	set factor 4
    } else {
	set factor 0
    }
    set delta [expr {($depth - 1) * $factor}]
    incr width $delta
    incr x $delta

    foreach mode {indented collapsed expanded} {
	image create photo tablelist_${treeStyle}_${mode}Img$depth \
	    -width $width -height $baseHeight
    }

    foreach mode {collapsed expanded} {
	tablelist_${treeStyle}_${mode}Img$depth copy \
	    tablelist_${treeStyle}_${mode}Img -to $x 0

	foreach modif {Sel Act SelAct} {
	    variable ${treeStyle}_${mode}${modif}Img
	    if {[info exists ${treeStyle}_${mode}${modif}Img]} {
		image create photo \
		    tablelist_${treeStyle}_${mode}${modif}Img$depth \
		    -width $width -height $baseHeight
		tablelist_${treeStyle}_${mode}${modif}Img$depth copy \
		    tablelist_${treeStyle}_${mode}${modif}Img -to $x 0
	    }
	}
    }
}
