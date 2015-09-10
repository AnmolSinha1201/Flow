#NoEnv
#include Gdip_All.ahk

pToken := Gdip_Startup()


FileRead, OutVar, *t source.c
Level1ProcessFile(OutVar) ;remove headers and only process main.

Parent := new EndPoint("START")
Last := new EndPoint("END")
global st := new Stack()
st.Push(Parent)
draw(OutVar)
st.Push(Last)

SewStates()
Final := st.Pop()
Gdip_SaveBitmapToFile(Final.pBitmap, "file.png")


Gdip_Shutdown(pToken)
ExitApp

SewStates()
{
	childElem := st.pop()
	while elem := st.Pop()
	{
		elem.joinbot(childElem)
		childElem := elem
	}
	st.push(childElem)
	
}

draw(lines)
{
	lines := Trim(lines, "`n")
	if(lines = "")
		return
	
	static Buffer
	static possibleInnerLoop := 0
	
	line := SubStr(lines, 1, InStr(lines, "`n") - 1)
	if(line = "")
		line := lines
	lines := SubStr(lines, StrLen(line) + 2)

	state := GetAlias(line)
	if(!state)
		Buffer := Buffer "`n" line
	
	if(lines = "" || state)
	{
		if(Buffer)
		{
			obj := new Operation(Trim(Buffer, "`n"))
			Buffer := ""
			Parent := st.pop()
			Parent.joinBot(obj)
			st.push(Parent)
		}
		if(state = 1)
		{
			obj := new Decision(line)
			if(substr(lines, 1, 1) = "{")
				lines := SubStr(lines, 3)
			st.push(obj)
			possibleInnerLoop := 1
		}
		else if(state = 2)
			possibleInnerLoop := 1
		else if(state = 3)
		{
			if(possibleInnerLoop)
			{
				obj := st.pop()
				obj.CompleteLoop()
				obj.DrawBufferedPartialFalse()
				st.push(obj)
				possibleInnerLoop := 0
			}
			else
			{
				obj := st.pop()
				Parent := st.pop()
				Parent.joinBot(obj)
				Parent.CompleteLoop()
				Parent.DrawBufferedPartialFalse()
				st.push(Parent)
			}
		}
	}
	
	draw(lines)
}

GetAlias(ByRef Line) ; 0 = print as it is, 1 = Loop, 2 = {, 3 = }, -1 = blank
{
	Line := Trim(Line, "`n`r")
	Line := Trim(Line)
	if(Line = "")
		return, -1
	if(SubStr(Line, 1, 3) = "int")
	{
		Line := "Declare " SubStr(Line, 4)
		Line := Trim(Line, ";")
		return, 0
	}
	; ladder for various declaration types
	else if(SubStr(Line, 1, 6) = "printf")
	{
		Dummy := "Print "
		pos := RegExMatch(Line, ",")
		while pos := RegExMatch(Line, "(\w+\[\w+\]\[\w+\]|\w+\[\w+\]|\w+)", OutVar, pos + StrLen(OutVar))
			Dummy := Dummy OutVar1 ","
		Dummy := Trim(Dummy, ",")
		if(Dummy = "")
		{
			RegExMatch(Line, "printf\(""(.*)""", OutVar)
			Dummy := OutVar1
		}
		Line := Dummy
		return, 0
	}
	else if(SubStr(Line, 1, 5) = "scanf")
	{
		Dummy := "Scan "
		pos := RegExMatch(Line, ",")
		while pos := RegExMatch(Line, "(\w+\[\w+\]\[\w+\]|\w+\[\w+\]|\w+)", OutVar, pos + StrLen(OutVar))
			Dummy := Dummy OutVar1 ","
		Line := Trim(Dummy, ",")
		return, 0
	}
	; loops
	else if(SubStr(Line, 1, 3) = "for")
	{
		RegExMatch(Line, "for\s*\((\w+\W*\d+)\s*;\s*(\w+\D*\d+)\s*;\s*(\w+\W+)\s*\)", OutVar)
		Line := OutVar1 "`n" OutVar2 "`n" OutVar3
		return, 1
	}
	else if(Line = "{")
		return, 2
	else if(Line = "}")
		return, 3
	
}

esc::ExitApp

Level1ProcessFile(ByRef OutVar)
{
	mainLevel := 0
	skipNextLine := 0
	Loop, Parse, OutVar, `n
	{
		Line := Trim(A_LoopField)
		if(skipNextLine)
		{
			skipNextLine := 0
			continue
		}
		if(InStr(A_LoopField, "#Include"))
			continue
		if(!mainLevel)
		{
			if(InStr(A_LoopField, "void main") || InStr(A_LoopField, "int main"))
			{
				mainLevel++
				if(SubStr(A_LoopField, 0, 1) != "{")
					skipNextLine := 1
			}
			continue
		}
		if(InStr(A_LoopField, "return"))
			continue
		if(InStr(A_LoopField, "{"))
			mainLevel++
		if(InStr(A_LoopField, "}"))
		{
			mainLevel--
			if(!mainLevel)
				break
		}
		dummy := dummy Line "`n"
	}
	OutVar := ""
	Loop, Parse, dummy, `n`r
		OutVar := OutVar A_LoopField "`n"
	OutVar := Trim(OutVar, "`n")
}


class Decision
{
	;0 = left, 1 = bot, 2 = right
	trueDir := 0
	falseDir := 2
	width := 200
	height := 200
	type := "Decision"
	__New(string)
	{
		pBitmap := Gdip_CreateBitmap(this.width, this.height)
		G := Gdip_GraphicsFromImage(pBitmap)
		Gdip_SetSmoothingMode(G, 4)
		pBrush := Gdip_BrushCreateSolid(0xffaaaaff)
		Gdip_FillPolygon(G, pBrush, "0," this.height // 2 "|" this.width // 2 ",0|" this.width "," this.height // 2 "|" this.width // 2 "," this.height)
		Gdip_DeleteBrush(pBrush)
		
		Write(G, string, 0, 0, this.width, this.height)
		this.pBitmap := pBitmap
		Gdip_DeleteGraphics(G)
	}
	
	__Delete()
	{
		Gdip_DisposeImage(this.pBitmap)
	}
	
	CompleteLoop() ;creates a loop for true
	{
		buffer := 20, LineWidth := 2
		
		width := this.width + 2*buffer
		height := this.height + 2*buffer
		
		pBitmap := Gdip_CreateBitmap(width, height)
		G := Gdip_GraphicsFromImage(pBitmap)
		
		Gdip_DrawImage(G, this.pBitmap, (width - this.width) // 2, buffer, this.width, this.height)
		
		pPen := Gdip_CreatePen(0xff000000, 2)
		Gdip_DrawLine(G, pPen, width/2, height - buffer, width/2, height)
		Gdip_DrawLine(G, pPen, width/2, height, 0, height)
		Gdip_DrawLine(G, pPen, 0, height, 0, 0)
		Gdip_DrawLine(G, pPen, 0, 0, width/2, 0)
		Gdip_DrawLine(G, pPen, width/2, 0, width/2, buffer)
		
		CreateArrow(pBitmap, G, width/2, buffer / 2, 0)
		
		Gdip_DeleteGraphics(G)
		Gdip_DeletePen(pPen)
		Gdip_DisposeImage(this.pBitmap)
		
		this.pBitmap := pBitmap
		this.width := width
		this.height := height
	}
	
	DrawBufferedPartialFalse()
	{
		buffer := 20, LineWidth := 2
		
		width := this.width + 2*buffer
		height := this.height + buffer
		
		pBitmap := Gdip_CreateBitmap(width, height)
		G := Gdip_GraphicsFromImage(pBitmap)
		
		Gdip_DrawImage(G, this.pBitmap, (width - this.width) / 2, 0, this.width, this.height)
		pPen := Gdip_CreatePen(0xff000000, 2)
		Gdip_DrawLine(G, pPen, (width + 200) / 2, 200 / 2 + buffer, width, 200 / 2 + buffer)
		Gdip_DrawLine(G, pPen, width, 200 / 2 + buffer, width, height)
		Gdip_DrawLine(G, pPen, width, height, width / 2, height)
		
		CreateArrow(pBitmap, G, ((width + 200) / 2 + width) / 2, 200 / 2 + buffer, 1)
		Write(G, "F", ((width + 200) / 2 + width) / 2, 200 / 2 + buffer, 80, 80)
		
		Gdip_DeleteGraphics(G)
		Gdip_DeletePen(pPen)
		Gdip_DisposeImage(this.pBitmap)
		
		this.pBitmap := pBitmap
		this.width := width
		this.height := height
		
		this.FalsePos := height
	}
	
	joinBot(ByRef obj)
	{
		obj_pBitmap := obj.pBitmap
		obj_width := Gdip_GetImageWidth(obj_pBitmap)
		obj_height := Gdip_GetImageHeight(obj_pBitmap)
		
		width := max(obj_width, this.width)
		
		pBitmap := Gdip_CreateBitmap(width, this.height + obj_height + 50)
		G := Gdip_GraphicsFromImage(pBitmap)
		
		Gdip_DrawImage(G, this.pBitmap, (width - this.width) // 2, 0, this.width, this.height)
		Gdip_DrawImage(G, obj_pBitmap, (width - obj_width) / 2, this.height + 50, obj_width, obj_height)
		
		pPen := Gdip_CreatePen(0xff000000, 2)
		Gdip_DrawLine(G, pPen, width/2, this.height, width/2, this.height + 50)
		
		CreateArrow(pBitmap, G, width/2, this.height + 50 /2, 0)
		
		Gdip_DeleteGraphics(G)
		Gdip_DeletePen(pPen)
		Gdip_DisposeImage(this.pBitmap)
		obj := ""
		this.pBitmap := pBitmap
		this.width := width
		this.height := Gdip_GetImageHeight(pBitmap)
	}
}

class Operation
{	
	width := 200
	height := 100
	__New(string)
	{
		pBitmap := Gdip_CreateBitmap(this.width, this.height)
		G := Gdip_GraphicsFromImage(pBitmap)
		Gdip_SetSmoothingMode(G, 4)
		pBrush := Gdip_BrushCreateSolid(0xffaaaaff)
		Gdip_FillRectangle(G, pBrush, 0, 0, this.width, this.height)
		Gdip_DeleteBrush(pBrush)
		
		Write(G, string, 0, 0, this.width, this.height)
		this.pBitmap := pBitmap
		Gdip_DeleteGraphics(G)
	}
	
	__Delete()
	{
		Gdip_DisposeImage(this.pBitmap)
	}
	
	joinBot(ByRef obj)
	{
		obj_pBitmap := obj.pBitmap
		obj_width := Gdip_GetImageWidth(obj_pBitmap)
		obj_height := Gdip_GetImageHeight(obj_pBitmap)
		
		width := max(obj_width, this.width)
		
		pBitmap := Gdip_CreateBitmap(width, this.height + obj_height + 50)
		G := Gdip_GraphicsFromImage(pBitmap)
		
		Gdip_DrawImage(G, this.pBitmap, (width - this.width) / 2, 0, this.width, this.height)
		Gdip_DrawImage(G, obj_pBitmap, (width - obj_width) / 2, this.height + 50, obj_width, obj_height)
		pPen := Gdip_CreatePen(0xff000000, 2)
		Gdip_DrawLine(G, pPen, width/2, this.height, width/2, this.height + 50)
		
		CreateArrow(pBitmap, G, width/2, this.height + 50 /2, 0)
		
		Gdip_DeleteGraphics(G)
		Gdip_DeletePen(pPen)
		Gdip_DisposeImage(this.pBitmap)
		obj := ""
		this.pBitmap := pBitmap
		this.width := width
		this.height := Gdip_GetImageHeight(pBitmap)
	}
}

class EndPoint
{	
	width := 200
	height := 100
	type := "EndPoint"
	__New(string)
	{
		pBitmap := Gdip_CreateBitmap(this.width, this.height)
		G := Gdip_GraphicsFromImage(pBitmap)
		Gdip_SetSmoothingMode(G, 4)
		pBrush := Gdip_BrushCreateSolid(0xffaaaaff)
		Gdip_FillRoundedRectangle(G, pBrush, 0, 0, this.width, this.height, this.height//2)
		Gdip_DeleteBrush(pBrush)
		
		Write(G, string, 0, 0, this.width, this.height)
		this.pBitmap := pBitmap
		Gdip_DeleteGraphics(G)
	}
	
	__Delete()
	{
		Gdip_DisposeImage(this.pBitmap)
	}
	
	joinBot(ByRef obj)
	{
		obj_pBitmap := obj.pBitmap
		obj_width := Gdip_GetImageWidth(obj_pBitmap)
		obj_height := Gdip_GetImageHeight(obj_pBitmap)
		
		width := max(obj_width, this.width)
		
		pBitmap := Gdip_CreateBitmap(width, this.height + obj_height + 50)
		G := Gdip_GraphicsFromImage(pBitmap)
		
		Gdip_DrawImage(G, this.pBitmap, (width - this.width) / 2, 0, this.width, this.height)
		Gdip_DrawImage(G, obj_pBitmap, (width - obj_width) / 2, this.height + 50, obj_width, obj_height)
		pPen := Gdip_CreatePen(0xff000000, 2)
		Gdip_DrawLine(G, pPen, width/2, this.height, width/2, this.height + 50)
		
		CreateArrow(pBitmap, G, width/2, this.height + 50 /2, 0)
		
		Gdip_DeleteGraphics(G)
		Gdip_DeletePen(pPen)
		Gdip_DisposeImage(this.pBitmap)
		obj := ""
		this.pBitmap := pBitmap
		this.width := width
		this.height := Gdip_GetImageHeight(pBitmap)
	}
}

class Stack
{
	A := []
	push(ByRef num)
	{
		this.A.Insert(num)
	}
	pop()
	{
		dummy := this.A[this.A.MaxIndex()]
		this.A.Remove(this.A.MaxIndex())
		return, dummy
	}
	Total()
	{
		return, this.A.MaxIndex()
	}
	Peek()
	{
		return, this.A[this.A.MaxIndex()]
	}
}

CreateArrow(pBitmap, G, x, y, direction) ; 0 = bottom, 1 = right
{
	length := 10, width := 5
	pPen := Gdip_CreatePen(0xff000000, 2)
	if(!direction)
	{
		Gdip_DrawLine(G, pPen, x, y, x - width, y - length)
		Gdip_DrawLine(G, pPen, x, y, x + width, y - length)
	}
	else
	{
		Gdip_DrawLine(G, pPen, x, y, x - length, y - width)
		Gdip_DrawLine(G, pPen, x, y, x - length, y + width)
	}
	
}

max(a, b)
{
	return (a>b)?a:b
}

write(G, string, x, y, w, h)
{
	Options := "x" x "p y" y "p Centre vCentre cff000000 s20"
	Gdip_TextToGraphics(G, string, Options, "Arial", w, h)
}