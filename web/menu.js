//Author: Younes Bouab
//Date:   03-05-01
//Title:  Menu Generator: Menu.js
//Copyright: Younes Bouab 2001 
//Technical Support: bouaby@SUPEReDITION.com
////////////////////////////////////////////
////////////////////////////////////////////
//DO NOT CHANGE ANYTHING IN THIS FILE!
//"Config.js" is the file you can edit
////////////////////////////////////////////

/*******************************************/
//Dreamweaver Show/Hide/Obj Layer functions
/*******************************************/
function showHideLayers() { 
  var i,p,v,obj,args=showHideLayers.arguments;
  for (i=0; i<(args.length-2); i+=3) if ((obj=findObj(args[i]))!=null) { v=args[i+2];
    if (obj.style) { obj=obj.style; v=(v=='show')?'visible':(v='hide')?'hidden':v; }
    obj.visibility=v; }
}
function findObj(n, d) { 
  var p,i,x;  if(!d) d=document; if((p=n.indexOf("?"))>0&&parent.frames.length) {
    d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);}
  if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++) x=d.forms[i][n];
  for(i=0;!x&&d.layers&&i<d.layers.length;i++) x=findObj(n,d.layers[i].document);
  if(!x && document.getElementById) x=document.getElementById(n); return x;
}
function changeProp(objName,x,theProp,theValue) { 
  var obj = findObj(objName);
  if (obj && (theProp.indexOf("style.")==-1 || obj.style)) eval("obj."+theProp+"='"+theValue+"'");
}

function reloadPage(init) { 
  if (init==true) with (navigator) 
  {
    if ((appName=="Netscape")&&(parseInt(appVersion)==4)) 
    {
      document.pgW=innerWidth;
      document.pgH=innerHeight;
      onresize=reloadPage; 
    }
  }
  else if (innerWidth!=document.pgW || innerHeight!=document.pgH) {location.reload();}
}
reloadPage(true);

/******************************************/
// Initialize
/******************************************/
//Menu Array
Menu =new Array(); //Menu[x][0]=INDEX - Menu[x][1]=PARENT - Menu[x][2]=Text - Menu[x][3]=Image - Menu[x][4]=Roll Image - Menu[x][5]=URL 
var i=0;
var ii=0; //used in validation of Menu Array
var MaxMenuIndex=0;

//Default Layer Frame for IE and NS6.X
var Layer="\"<div id='\"+IDLABEL+\"' class='CBORDER' Style='Position:absolute; visibility:\"+VISIBILITY+\"; left:\"+(LEFT+NS6X)+\"px; top:\"+(TOP+NS6X)+\"px; width:\"+(WIDTH+NS6X)+\"px; height:\"+(HEIGHT+NS6X)+\"px; background-color:\"+MyLayerColor+\"; z-index:\"+ZINDEX+\"; URL(\"+MyURL+\")' \"";
var Layer_End="</div>";

LAYER= new Array();//Menu string FOR EACH ITEM
MOUSEOVEROUT=new Array();//HOLDS THE LAYERIDs that should have OnMouseOver && OnMouseOut for each menu
TOPLEFT=new Array(); //holds Top and left measures for each menu item
Parent_Children_ID=new Array();

//Layers Variables
var IDLABEL="";
var VISIBILITY="visible"; //default
var ZINDEX=0;
var MyURL="";

//Position function variables
var TopParent=TOP;
var LeftParent=LEFT;
var ORGWIDTH=WIDTH;
Parent_Child_Count=new Array(); //Counts the children of each Main Menu
var Main_Parent_Count=0; //Counts the number of the Main menu 

//Validation Variable
Error=false; 
SortingError=false; 

//NS CORRECTIONS
var NS_Table_Width_Corr=0;
var NS_Table_Heigth_Corr=0;
var NS6X=0; if(!document.all && document.getElementById) {NS6X=-2;} 


/******************************************/
//Add Menu item to Menu Array
/******************************************/
function AddMenu(ID, Parent_ID, Text, Image, RollImage, URL)
{ 
  //Validation
  var valid = "0123456789"; 
  var temp; 
  if(ID.length==0) {alert("The Menu #"+(ii+1)+" does not have an ID assigned"); Error=true;}
  //check if ID is composed 
  else 
  { 
    //Checking if number
    for(var j=0;j<ID.length;j++)
    {
      temp=ID.substring(j,j+1);
      if(valid.indexOf(temp)==-1) {alert("The ID of the Menu #"+(ii+1)+" should be a number value"); Error=true;}
    }
  }
  if(Parent_ID.length==0) {alert("The Menu #"+(ii+1)+" does not have a Parent_ID assigned"); Error=true;}
  //check if Parent_ID is composed of only numbers and dashes "-"
  else 
  { 
    //Checking if number
    for(var j=0;j<Parent_ID.length;j++)
    {
      temp=Parent_ID.substring(j,j+1);
      if(valid.indexOf(temp)==-1) {alert("The Parent_ID of the Menu #"+(ii+1)+" should be a number value"); Error=true;}
    }
  }
  if(Text.length==0 && Image.length==0) {alert("The Menu #"+(ii+1)+" should have either an image or a text assigned"); Error=true;}
  ii++;
   
  Menu[i] = new Array();    
  if(!Error)
  {
     for (var j=0; j < 6 ;j++)
     {         
        if (j==0) { Menu[i][0]=ID;      } 
        if (j==1) { Menu[i][1]=Parent_ID;     } 
        if (j==2) { Menu[i][2]=Text;       }
        if (j==3) { Menu[i][3]=Image;      }
        if (j==4) { Menu[i][4]=RollImage;  } 
        if (j==5) { Menu[i][5]=URL;        }
     }
     i++; 
     MaxMenuIndex = i;
  }  
  //Reinitialze Error Value
  Error=false;
}

/******************************************/
//Build Menus
/******************************************/
function Build()
{
    //Browser Check
    NS4XCorrection()
    
    //Initilize Position Variables
    for (var j=0;j<MaxMenuIndex;j++)
    { 
      TOPLEFT[j]=new Array();
      Parent_Child_Count[j]=0;
      MOUSEOVEROUT[j]=new Array(); 
      Parent_Children_ID[j]=new Array();  
      TOPLEFT[j][0]=0;
      TOPLEFT[j][1]=0;
    }   
 
   //Sort and check menu for errors
   if(Sort==1) {Sorting();}

   if(!SortingError)
   {  
   
    //Build CSS: Layer Border
    if (LayerBorderSize!="")
    {document.writeln("<Style type=\"text/css\">");
     document.writeln(".CBORDER {");
     document.writeln(" width:"+WIDTH+"px;"); 
     document.writeln(" heigth:"+HEIGHT+"px;");  
     document.writeln(" border: "+LayerBorderStyle+" "+LayerBorderColor+" "+LayerBorderSize+"px;"); 
     document.writeln("}\n</style>\n");
    }
          
   //Build each Menu
   for (i=0; i < MaxMenuIndex;i++)
   {
     //Calculates Main Positions, visibility, and determines ID
     CalcLayerVariables(i); 

     //Global Properties
     var MyLayerColor=LayerColor;
     var MyLayerRollColor=LayerRollColor;
     //Parent Color
     if(Menu[i][0]==Menu[i][1])
     {
        //BG ROLL Color 
        if (Main_Parent_LayerColor!="" )
        {
            MyLayerColor=Main_Parent_LayerColor;
        }            
     }     
     //Layer Code  
     LAYER[i]=eval(Layer);           
   }

   //Add samelevel mouse events
   SameLevelMouseEvents(); 

   //Build
   for (var j=0;j<MaxMenuIndex;j++)
   {
     var MyFONT=FONT;
     var MyFONTCOLOR=FONTCOLOR;
     var MyFONTSIZE=FONTSIZE;
     var MyFONTSTYLE=FONTSTYLE;
     var MySTARTCHAR=START_CHAR;

     //Parent/Children FONT Properties
     if(Menu[j][0]==Menu[j][1])
     {   
        if(Main_Parent_FONT!="")
        {
            MyFONT=Main_Parent_FONT;
        }  
        if(Main_Parent_FONTCOLOR!="")
        {
            MyFONTCOLOR=Main_Parent_FONTCOLOR;
        }  
        if(Main_Parent_FONTSIZE!="")
        {
            MyFONTSIZE=Main_Parent_FONTSIZE;
        }    
        if(Main_Parent_FONTSTYLE!="")
        {
            MyFONTSTYLE=Main_Parent_FONTSTYLE;
        }  
        if(Main_Parent_START_CHAR!="")
        {
            MySTARTCHAR=Main_Parent_START_CHAR;
        }        
     }  


     var MOUSEOVERCODE="";
     var MOUSEOUTCODE="";
     for (var jj=0;jj<MaxMenuIndex;jj++)
     {
       if(MOUSEOVEROUT[j][jj]!=null)
       {
          MOUSEOVERCODE=MOUSEOVERCODE+"showHideLayers('"+MOUSEOVEROUT[j][jj]+"','','show');";
          MOUSEOUTCODE=MOUSEOUTCODE+"showHideLayers('"+MOUSEOVEROUT[j][jj]+"','','hide');";
       } 
       else
       { 
          MOUSEOVERCODE=MOUSEOVERCODE+"PathRoad("+j+",1)";           
          MOUSEOUTCODE=MOUSEOUTCODE+"PathRoad("+j+",0)";          
          break;
       } 
     } 

     //Linking the entire layer area
     document.write(LAYER[j]+" onMouseOver=\""+MOUSEOVERCODE+"\" onMouseOut=\""+MOUSEOUTCODE+"\"");
     if(Menu[j][5]!="") //{document.write(" class=\"location.href='"+Menu[j][5]+"';\"");}
     {document.write(" onClick=\"location.href='"+Menu[j][5]+"';\"");}
     document.write(" >");     
     
     var LINK="";      
     //display link if any and setup rollover image if any
     if(Menu[j][5]!="")
     {   
        LINK="<A href=\""+Menu[j][5]+"\">";
     }
     
     //Image Code
     var ImageCode="";
     if(Menu[j][3]!="")
     {
       ImageCode=ImageCode+"<IMG Name='Image"+Menu[j][0]+"' SRC='"+Menu[j][3]+"' BORDER=0>";  
     } 
     
     //Fonts if any 
     var FONT_PROPERTIES="";  
     if(MyFONT!="")     {FONT_PROPERTIES=" Type='"+MyFONT+"'";}
     if(MyFONTSIZE!="") {FONT_PROPERTIES=FONT_PROPERTIES+" size='"+MyFONTSIZE+"'";}
     if(MyFONTCOLOR!=""){FONT_PROPERTIES=FONT_PROPERTIES+" color='"+MyFONTCOLOR+"'";}
     if(FONT_PROPERTIES!="" ){FONT_PROPERTIES="<FONT "+FONT_PROPERTIES+">";}
     if(MyFONTSTYLE!=""){FONT_PROPERTIES="<"+MyFONTSTYLE+">"+FONT_PROPERTIES;}
     

     //Display IMAGE  and TEXT
     document.write("<table border='0' WIDTH='100%' height='100%' cellpadding='0' cellspacing='0'><tr>");     

     if(ImageCode!="")
     {
       document.write("<td ");
       if(HALIGN !=""){document.write(" align='"+HALIGN+"' ");}
       if(VALIGN !=""){document.write(" valign='"+VALIGN+"' ");}
       document.write(">");

       if(LINK!="") {document.write(LINK);}
       document.write(ImageCode);
       if(LINK!=""){document.write("</a>");}
       document.write("</td>"); 
     }

     if(Menu[j][2]!="")
     {
       document.write("<td ");
       if(HALIGN !=""){document.write("  align='"+HALIGN+"' ");}
       if(VALIGN !=""){document.write(" valign='"+VALIGN+"' ");}
       document.write(">");

       if(FONT_PROPERTIES!="") {document.write(FONT_PROPERTIES);}
       document.write(MySTARTCHAR);
       if(LINK!="") {document.write(LINK);} 
       document.write(Menu[j][2]);       
       if(LINK!=""){document.write("</a>");}
       if(FONT_PROPERTIES!="")  {document.write("</FONT>");} 
       if(MyFONTSTYLE!="") {document.write("</"+MyFONTSTYLE+">");}
       document.write("</td>"); 
     }
     document.write("</tr></table>");

      //close layer
      document.writeln(Layer_End);
   }
  }   
}
/*********************************************************************************/
////Sort in-case not ordered and check if every menu parent has a matching index
/********************************************************************************/
function Sorting()
{
  //Place all Parents before children
  for (i=0; i<(MaxMenuIndex-1);i++)
  { 
    TheParent=Menu[i][1];    
    for (j=(i+1); j<MaxMenuIndex; j++)
    { 
       if(Menu[j][0]==TheParent)    
       {              
           for(var f=0;f<6;f++)
           {           
             temp=Menu[i][f];               
             Menu[i][f]=Menu[j][f];
             Menu[j][f]=temp;  
           }
           i=0;   
           break;           
       }
    } 
  }
}
/******************************************/
//Netscape 4.X Correction 
/******************************************/
function NS4XCorrection()
{
  if(document.layers)
  {
   Layer="\"<layer class='CBORDER' id='\"+IDLABEL+\"' position='absolute' visibility='\"+VISIBILITY+\"' left='\"+LEFT+\"' top='\"+TOP+\"' width='\"+WIDTH+\"' height='\"+HEIGHT+\"' bgcolor='\"+MyLayerColor+\"' z-index='\"+ZINDEX+\"'\" ";    
   Layer_End="</layer>";
  }
  NS_Table_Width_Corr=5;
  NS_Table_Heigth_Corr=5;
}

function NS4ImageCorrect(Index)
{
  var NS4FIX="";
  if(document.layers)
  {
     return "layers.Layer"+Menu[Index][0]+".document.";
  }
  return ""; 
}  

/******************************************/
//Calculates Menu Item Position                            
/******************************************/
function CalcLayerVariables(Index)
{
       var ID= Menu[Index][0];
       var Parent_ID= Menu[Index][1];

       //if Main Parent   
       if (ID==Parent_ID)
       {   
          //Menu Type  
          if(MENU_TYPE==1)
          {  
            TOP=TopParent; 
            LEFT=(Main_Parent_Count * WIDTH)+ LeftParent - (LayerBorderSize*Main_Parent_Count);  
          }
          else
          {
            TOP=(Main_Parent_Count * HEIGHT)+TopParent - (LayerBorderSize*Main_Parent_Count);
            LEFT=LeftParent;  
          }
          TOPLEFT[Index][0]=TOP;        
          TOPLEFT[Index][1]=LEFT;                   
          IDLABEL="Layer"+Menu[i][0];        
          VISIBILITY="visible";
          ZINDEX=100; //on top of the first 99 layers in the page!
          WIDTH=((+ORGWIDTH)-(+LayerBorderSize));

          Main_Parent_Count++;                
       }
       //Child
       else 
       {  
          //Find Parent        
          ChildofAParent=false;        
          var ParentIndex=0; 
          for (var j=0;j<MaxMenuIndex;j++)
          { 
            if (Menu[j][0]== Parent_ID)
            {  
               //collecting Children of Parents 
               for (var g=0;g<MaxMenuIndex;g++)
               {
                 if(Parent_Children_ID[j][g]==null)
                 { Parent_Children_ID[j][g]=IDLABEL;
                   break;
                 }
               } 
               if(Menu[j][0]==Menu[j][1]) 
               {ChildofAParent=true;}
               ParentIndex=j; 
               break;
            }
          }
          //if child of a Main Parent and Menu Type is Horizental                        
          if(ChildofAParent && MENU_TYPE==1)
          { 
             Parent_Child_Count[ParentIndex] = Parent_Child_Count[ParentIndex] + 1;                                   
             TOP=TopParent+(Parent_Child_Count[ParentIndex] * HEIGHT) - ((Parent_Child_Count[ParentIndex])*LayerBorderSize);
             LEFT=TOPLEFT[ParentIndex][1];                  
             ZINDEX=101; //on top of the first 100 layers in the page!                  
          } 
          //if a child of a child  
          else
          { 
             Parent_Child_Count[ParentIndex] = Parent_Child_Count[ParentIndex] + 1; 
             TOP=(TOPLEFT[ParentIndex][0])+((Parent_Child_Count[ParentIndex]-1) * HEIGHT) - ((Parent_Child_Count[ParentIndex]-1)*LayerBorderSize) + TOP_OFFSET;
             LEFT=(WIDTH + TOPLEFT[ParentIndex][1]) - LEFT_OFFSET - LayerBorderSize;               
             if(ChildofAParent){ZINDEX=101;}else{ZINDEX=102;} //on top of the first 100 layers in the page,100 is Main Parent and 101 is Parent
          }        
          VISIBILITY="hidden";  
          IDLABEL="Layer"+Menu[Index][0];          
          TOPLEFT[Index][0]=TOP;                                              
          TOPLEFT[Index][1]=LEFT;
          WIDTH=((+ORGWIDTH)-(+LayerBorderSize));
       }    
}
/******************************************/
//Generates onMouseOver Event for same 
//level layers
//                           
/******************************************/
function SameLevelMouseEvents()
{
  //1 showHide Main Parent children
  for(var u=0;u<MaxMenuIndex;u++)
  {
     //if Main Parent  
     if (Menu[u][0]==Menu[u][1])
     { 
          for(var y=0;y<MaxMenuIndex;y++)
          {
             //if not the one being tested and has the same parent
             if(y!=u && (Menu[y][1]==Menu[u][0]))
             { 
               for(var z=0;z<MaxMenuIndex;z++) {if(MOUSEOVEROUT[u][z]==null) {MOUSEOVEROUT[u][z]="Layer"+Menu[y][0];break;}} 
             }
          } 
      }
   }
   //2 show hide same Parent menu items
   for(var u=0;u<MaxMenuIndex;u++)
   {
      if (Menu[u][1]!=Menu[u][0])
      {
         for(var z=0;z<MaxMenuIndex;z++) {if(MOUSEOVEROUT[u][z]==null) {MOUSEOVEROUT[u][z]="Layer"+Menu[u][0];break;}} 
         for(var y=0;y<MaxMenuIndex;y++)
          {
             //if not the one being tested and has the same parent and bot the parent menu
             if(y!=u && (Menu[y][1]==Menu[u][1]) && (Menu[y][0]!=Menu[y][1]) )
             { 
                for(var z=0;z<MaxMenuIndex;z++) {if(MOUSEOVEROUT[u][z]==null) {MOUSEOVEROUT[u][z]="Layer"+Menu[y][0];break;}}  
             }
          }
      }
   } 
   //3 show hide children of non Main Parent
   var same="";
   for(var u=0;u<MaxMenuIndex;u++)
   {
       if (Menu[u][1]!=Menu[u][0])
       {
          for(var y=0;y<MaxMenuIndex;y++)
          {
             if ((Menu[u][0]==Menu[y][1]) && (Menu[y][0]!=Menu[y][1]) && y!=u)
             {
                for(var z=0;z<MaxMenuIndex;z++) 
                {if(MOUSEOVEROUT[u][z]==null) {MOUSEOVEROUT[u][z]="Layer"+Menu[y][0];same=z;break;}}                 
                //Pass Parent's show hide to the children
                for(var z=0;z<MaxMenuIndex;z++) 
                {
                  if(MOUSEOVEROUT[u][z]!=null) 
                  {
                    for(var x=0;x<MaxMenuIndex;x++) 
                    {
                      if(MOUSEOVEROUT[y][x]==null) {MOUSEOVEROUT[y][x]=MOUSEOVEROUT[u][z];break;}
                    }
                  }
                  else {break;}
                }  
             }
          }
       }
   }   

}
/******************************/
//PathColor
/******************************/
function PathRoad(Parent,flag)
{
  AtStart=false;
  while (!AtStart) 
  {  
     //change both layer color and image     
     if(flag==1) //Roll
     {
       //Layer's Image: Browser Check 
       if(Main_Parent_LayerRollColor!="" && Menu[Parent][0]==Menu[Parent][1]) {MyLayerRollColor=Main_Parent_LayerRollColor;} else {MyLayerRollColor=LayerRollColor;}        
       if(Menu[Parent][4]!="")
       {
         eval("document."+NS4ImageCorrect(Parent)+"images.Image"+Menu[Parent][0]+".src='"+Menu[Parent][4]+"'"); 
       }

       //Layer Color: Browser Check 
       if(document.layers)
       {
         eval("changeProp('Layer"+Menu[Parent][0]+"','','document.bgColor','"+MyLayerRollColor+"','LAYER')");
       }
       else  if(document.getElementById || document.all)
       {

         eval("changeProp('Layer"+Menu[Parent][0]+"','','style.backgroundColor','"+MyLayerRollColor+"','DIV')");
       }
     }
     else //Origin Image and Color
     {
       //Layer's Image: Browser Check 
       if(Main_Parent_LayerColor!="" && Menu[Parent][0]==Menu[Parent][1]) {MyLayerColor=Main_Parent_LayerColor;} else {MyLayerColor=LayerColor;} 
       if(Menu[Parent][3]!="")
       {
         eval("document."+NS4ImageCorrect(Parent)+"images.Image"+Menu[Parent][0]+".src='"+Menu[Parent][3]+"'"); 
       } 
       //Layer Color: Browser Check  
       if(document.layers){eval("changeProp('Layer"+Menu[Parent][0]+"','','document.bgColor','"+MyLayerColor+"','LAYER')");}
       else if(document.getElementById || document.all){eval("changeProp('Layer"+Menu[Parent][0]+"','','style.backgroundColor','"+MyLayerColor+"','DIV')");}      
     }
     if(Menu[Parent][0] == Menu[Parent][1])
     {
       AtStart=true;
     }
     Parent=INDEXof(Menu[Parent][1]);  
  }
}
//Find the index of the Menu Array with the Parent: Parent
function INDEXof(Parent)    
{
 for(var j=0;j<MaxMenuIndex;j++)
 {
   if(Menu[j][0]==Parent)
   {
     return (j);
   }  
 } 
}