;============================================================================
; Memory Game
; by Alto Fluff - October 2025
;============================================================================

;============================================================================
; Assembler Setup
;============================================================================

	PROCESSOR	6502

;============================================================================
; Basic Upstart - Use Basic to call our assembly program
; 10 SYS16384
;============================================================================
	
	ORG		$0801

	; byte is an alias for dc.b

	; address pointer to the basic line after this one, $080C
	byte	$0C, $08


	; Basic line 10 is actually line 0010 (decimal),
	; stored in little-endian - 10, 00 / $0A, $00
	; $9E is the BASIC token for the command SYS
	; [eol] = end of line / null terminator

	;        10   00  SYS     1    6    3    8    4  [eol]
	byte 	$0A, $00, $9E,  $31, $36, $33, $38, $34, $00


	; address pointer to the basic line after this one, $0000
	; $0000 means no more basic, therefore end of basic program
	byte	$00, $00


;============================================================================
; Our Program Starts at 16384
; Bank 0 is left for our GFX
;============================================================================

    ORG 	$4000   ; Address 16384

Start_Program:
Initialise_Program:

	;set border to blue
	LDX #6
	STX $D020

	; disable Shift-Commodore Key character swap
	LDX #$80
	STX $0291

	; reset sound memory
	LDX #24
	LDA #0
.Sound_Loop:
	STA SID_Location,X
	DEX
	BPL .Sound_Loop

	LDA #5
	STA Board_Width
	JSR Set_Board_Size_Variables

	; set keyboard buffer to 1
	LDA #1
	STA Maximum_Keyboard_Buffer_Size

	; disable key hold
	LDA #$40
	STA $028a

Title_Screen:
	JSR Print_Title_Screen

Wait_Title_Screen:
	JSR GETIN
	CMP #0
	BEQ Wait_Title_Screen
	
	JMP Menu_Screen

Restart_Game:
	; clear the screen
	LDX #<Str_Clr_Home
	LDA #>Str_Clr_Home		
	JSR Print_Text_To_Screen

	; initialise variables
	LDA #$FF
	STA	Tile_Uncovered

	LDA #0
	STA Current_Grid_Position
	STA Player_Score
	STA Computer_Score
	STA Computer_Aware_Of_Tile

	LDA #1
	STA	Current_Player

	JSR Set_Board_Size_Variables
	JSR Print_Empty_Board
	JSR Print_Score_Panel
	JSR Setup_Tile_Shuffle_Sound

	;Save cycles if the computer isn't playing this round
	LDA Menu_Player_Count
	CMP #3
	BCC .Skip_Resetting_Computer_Memory
	
	JSR Reset_Computer_Memory_Bank

.Skip_Resetting_Computer_Memory:
	JSR Initialise_Board_Tile_State
	JSR Print_Shuffling_Box
	JSR Pick_Tiles_For_Board

	JSR Clear_Shuffling_Box
	JSR Print_Covered_Board_Tiles
	JSR Clear_Cursor_Location
	JSR Highlight_Cursor_Location

	LDX #0
	STX Keyboard_Buffer_Size
	
Wait_Key:
	; Get a character from the input - BASIC equivalent: GET A$
	; Wait for a key to be pressed	
	
	JSR GETIN
	CMP #0
	BEQ Wait_Key

.Check_W_Key
	CMP #"W"
	BNE .Check_S_Key
	JMP Move_Cursor_Up

.Check_S_Key:
	CMP #"S"
	BNE .Check_A_Key
	JMP Move_Cursor_Down

.Check_A_Key:
	CMP #"A"
	BNE .Check_D_Key
	JMP Move_Cursor_Left

.Check_D_Key:
	CMP #"D"
	BNE .Check_Up_Cursor
	JMP Move_Cursor_Right

.Check_Up_Cursor
	CMP #145
	BNE .Check_Down_Cursor
	JMP Move_Cursor_Up

.Check_Down_Cursor:
	CMP #17
	BNE .Check_Left_Cursor
	JMP Move_Cursor_Down

.Check_Left_Cursor:
	CMP #157
	BNE .Check_Right_Cursor
	JMP Move_Cursor_Left

.Check_Right_Cursor:
	CMP #29
	BNE .Check_Return_Key
	JMP Move_Cursor_Right

.Check_Return_Key
	CMP #13
	BNE Wait_Key
	JMP Check_Selection


Move_Cursor_Up:
	LDA Current_Grid_Position
	SEC
	SBC Board_Width
	BMI Move_Cursor_Incorrect

	CLC
	LDA Board_Width
	EOR #$FF
	ADC #1
	STA Cursor_Offset

	JSR Move_Cursor_Continue
	JMP Wait_Key

Move_Cursor_Down:
	CLC
	LDA Current_Grid_Position
	ADC Board_Width
	CMP Board_Size
	BPL Move_Cursor_Incorrect
	
	LDA Board_Width
	STA Cursor_Offset
	JSR Move_Cursor_Continue
	JMP Wait_Key

Move_Cursor_Left:
	LDA Current_Grid_Position
	CMP #0
	BEQ Move_Cursor_Incorrect

Move_Cursor_Left_Check_Modulus:
	SEC
Move_Cursor_Left_Check_Modulus_Loop:
	SBC Board_Width
	BEQ Move_Cursor_Incorrect
	BPL Move_Cursor_Left_Check_Modulus_Loop

	LDA #$FF
	STA Cursor_Offset
	JSR Move_Cursor_Continue
	JMP Wait_Key

Move_Cursor_Right:
	LDA Current_Grid_Position
	CLC
	ADC #1
	CMP Board_Size
	BEQ Move_Cursor_Incorrect

Move_Cursor_Right_Check_Modulus:
	SEC
Move_Cursor_Right_Check_Modulus_Loop:
	SBC Board_Width
	BEQ Move_Cursor_Incorrect
	BPL Move_Cursor_Right_Check_Modulus_Loop

	LDA #$01
	STA Cursor_Offset
	JSR Move_Cursor_Continue
	JMP Wait_Key
	
Move_Cursor_Continue:
	JSR Play_Cursor_Positive_Sound
	JSR Clear_Cursor_Location
	
	CLC
	LDA Current_Grid_Position
	ADC Cursor_Offset
	STA Current_Grid_Position

	JSR Highlight_Cursor_Location
	RTS

Move_Cursor_Incorrect:
	JSR Play_Cursor_Negative_Sound
	JMP Wait_Key

;============================================================================
; Subroutine - Check_Selection
; Parameters:
;
; Affects:
;	- A, X, Y
;============================================================================
	SUBROUTINE

Check_Selection:
	; Check if tile is selectable
	LDX Current_Grid_Position
	LDA Board_Tile_State_Array,X
	CMP #0
	BEQ .Check_User_Select_Tile_Twice

.Reject_User_Input:
	JMP Process_Reject_User_Input

.Check_User_Select_Tile_Twice:
	LDA Current_Grid_Position
	CMP Tile_Uncovered
	BNE .Accept_Input

	LDA Menu_Player_Count
	CMP #3
	BCC .Reject_User_Input
	
	LDA Menu_Player_Count
	CMP #3
	BNE .Accept_Input
	LDA Current_Player
	CMP #1
	BEQ .Reject_User_Input
	CMP #2
	BEQ .Computer_Turn
	JMP .Accept_Input

.Computer_Turn
	JMP Process_Computer_Turn

.Accept_Input:
	JSR Uncover_Tile

	LDA Tile_Uncovered
	CMP #$FF
	BNE .Check_If_Computer_Probability_Needed

	; Bookmark current tile index
	LDA Current_Grid_Position
	STA Tile_Uncovered

.Check_If_Computer_Probability_Needed:
	LDA Menu_Player_Count
	CMP #3
	BCC .Check_Selection__Continue

	JSR Calculate_Computer_Probability

.Check_Selection__Continue:
	LDA Tile_Uncovered
	CMP Current_Grid_Position
	BNE .Continue

	LDA Menu_Player_Count
	CMP #3
	BCC .Next_Key

	LDA Current_Player
	CMP #1
	BNE .Check_For_Computer_Turn

	LDA Menu_Player_Count
	CMP #3
	BNE .Check_For_Computer_Turn	

.Next_Key:
	LDA #0
	STA Keyboard_Buffer_Size
	JMP Wait_Key

.Check_For_Computer_Turn:
	LDA Current_Player
	CMP #2
	BNE .Continue

	LDA Menu_Player_Count
	CMP #3
	BNE .Continue

	JMP Process_Computer_Turn

.Continue:
	LDA #0
	STA Computer_Aware_Of_Tile
	STA Keyboard_Buffer_Size

	LDX Current_Grid_Position
	LDA Board_Tile_Array,X
	STA .Temp_Tile

	LDX Tile_Uncovered
	LDA Board_Tile_Array,X
	CMP .Temp_Tile
	BEQ Tile_Matched

	LDY #$FF
	JSR Delay
	JSR Delay

	; Temporarily store the cursor location
	LDA Current_Grid_Position
	STA .Temp_Position

	JSR Cover_Tile	

	; Set the previous tile to the cursor location
	LDA Tile_Uncovered
	STA Current_Grid_Position

	JSR Cover_Tile

	; Restore the cursor location
	LDA .Temp_Position
	STA Current_Grid_Position

	; Reset uncovered tile to make the next turn, the first tile
	LDA #$FF
	STA Tile_Uncovered

	LDA Menu_Player_Count
	CMP #2
	BCC .Set_Player_1

	LDA Current_Player
	CMP #1
	BNE .Set_Player_1

	LDA #2
	STA Current_Player
	JMP .Set_Cursor_Highlight_Colour

.Set_Player_1:
	LDA #1
	STA Current_Player

.Set_Cursor_Highlight_Colour:
	JSR Clear_Cursor_Location
	JSR Highlight_Cursor_Location

	LDA #2
	CMP Current_Player
	BNE .Next_Key_2

	LDA Menu_Player_Count
	CMP #3
	BNE .Next_Key_2 

.Jump_To_Computer_Turn:
	JMP Process_Computer_Turn

.Next_Key_2:
	LDA #0
	STA Keyboard_Buffer_Size
	JMP Wait_Key

.Temp_Tile:		BYTE	0
.Temp_Position:	BYTE	0

;============================================================================
; Subroutine - Process_Reject_User_Input
; Parameters:
;
; Affects:
;	- A
;============================================================================
	SUBROUTINE

Process_Reject_User_Input:
	JSR Play_Cursor_Negative_Sound

	LDA #0
	STA Keyboard_Buffer_Size
	JMP Wait_Key

;============================================================================
; Subroutine - Tile_Matched
; Parameters:
;
; Affects:
;	- A, X
;============================================================================
	SUBROUTINE

Tile_Matched:
	LDA Current_Player
	CMP #1
	BNE .Increment_Player_2_Score

.Increment_Player_1_Score:
	INC Player_Score
	JMP .Print_Score_Update

.Increment_Player_2_Score:
	INC Computer_Score

.Print_Score_Update:
	JSR Print_Score_Panel

	LDA Current_Player
	CMP #1
	BNE .Play_Player_2_Match_Sound
	JSR Play_Player_1_Match_Sound
	JMP .Set_Tile_Colour_To_Current_Player

.Play_Player_2_Match_Sound:
	JSR Play_Player_2_Match_Sound

.Set_Tile_Colour_To_Current_Player:
	LDA Current_Player

	LDX Current_Grid_Position
	STA Board_Tile_State_Array,X

	LDX Tile_Uncovered
	STA Board_Tile_State_Array,X

	LDX Current_Grid_Position
	STX .Temp_Current_Position

	JSR Update_Tile_Colour

	LDX Tile_Uncovered
	STX Current_Grid_Position

	JSR Update_Tile_Colour

	LDX .Temp_Current_Position
	STX Current_Grid_Position	

	LDA #$FF
	STA Tile_Uncovered

	JSR Update_Tile_Still_Covered_Array

	CLC
	LDA Player_Score
	ADC Computer_Score
	CMP Tiles_Required
	BNE .Continue_Game

	JMP End_Game

.Continue_Game:
	LDA Current_Player
	CMP #2
	BNE .Ready_Up_Next_Key

	LDA Menu_Player_Count
	CMP #3
	BEQ Process_Computer_Turn

.Ready_Up_Next_Key
	LDA #0
	STA Keyboard_Buffer_Size

	JMP Wait_Key

.Temp_Current_Position:		BYTE	0

;============================================================================
; Subroutine - Update_Tile_Still_Covered_Array
; Parameters:
;
; Used for updating a set of known uncovered tiles that the computer can
; randomly pick from.
;
; Saves Brute-forcing the Board_Tile_State_Array for available tile locations
;============================================================================
	SUBROUTINE

Update_Tile_Still_Covered_Array:
	; reduce the remaining uncovered tile count by two
	DEC Tiles_Still_Uncovered_Count
	DEC Tiles_Still_Uncovered_Count

	LDA Tiles_Still_Uncovered_Count
	CMP #$FF
	BEQ .Return

.Process:
	LDX #0
	STX .Next_Uncovered_Array_Index ; used as the Tile_Still_Uncovered loop counter
.Loop:
	LDA Board_Tile_State_Array,X
	CMP #0
	BNE .Check_Next

	; transfer X for storage
	TXA
	LDX .Next_Uncovered_Array_Index
	STA Tiles_Still_Uncovered_Array,X

	; set next index in Tiles_Still_Uncovered_Array
	INC .Next_Uncovered_Array_Index

	; restore X
	TAX

.Check_Next
	INX
	CPX Board_Size
	BMI .Loop

.Return
	RTS

.Next_Uncovered_Array_Index:		BYTE	0

;============================================================================
; Subroutine - Process_Computer_Turn
; Parameters:
;
; Affects:
;	- A, X, Y
;============================================================================
	SUBROUTINE

Process_Computer_Turn:
	LDY #$FF
	JSR Delay

	LDA Computer_Aware_Of_Tile
	CMP #1
	BEQ .Set_Next_Tile

	; Check current position for a match
	LDX Current_Grid_Position
	LDA Board_Tile_Array,X
	ASL ; multiply by two to get the memory for that tile
	TAX
	LDA Computer_Memory_Bank,X

	CMP #$FF
	BEQ .Compter_Known_Tile_Recheck

	INX
	LDA Computer_Memory_Bank,X
	CMP #$FF
	BEQ .Compter_Known_Tile_Recheck

	LDX Current_Grid_Position
	LDA Board_Tile_State_Array,X
	CMP #0
	BNE .Compter_Known_Tile_Recheck

	LDA #1
	STA Computer_Aware_Of_Tile

	; Did it find a match?
.Compter_Known_Tile_Recheck:
	LDA Computer_Aware_Of_Tile
	CMP #1
	BEQ .Set_Next_Tile

	LDA Tile_Uncovered
	CMP #0
	BCS .No_Match

	; Doesn't know a match for this pair.
    ; Does it know any other matches?

	LDY #0
.Find_Other_Match_Loop:
	TYA
	ASL ; multiply by two as the matches are stored as [ first_tile, second_tile ]
	TAX

	; check second location for matched tile
	INX
	LDA Computer_Memory_Bank,X
	CMP #$FF
	BEQ .Continue_Loop

	; check first location for matched tile
	DEX
	LDA Computer_Memory_Bank,X
	CMP #$FF
	BEQ .Continue_Loop

	TAX
	LDA Board_Tile_State_Array,X
	CMP #0
	BNE .Continue_Loop

	LDA #1
	STA Computer_Aware_Of_Tile

	TYA
	ASL ; multiply by two as the matches are stored as [ first_tile, second_tile ]
	TAX
	LDA Computer_Memory_Bank,X
	STA rnd_end

	JMP .Computer_Found_Match_Check

.Continue_Loop:
	INY
	CPY Tiles_Required
	BNE .Find_Other_Match_Loop
	

.Computer_Found_Match_Check:
	LDA Computer_Aware_Of_Tile
	CMP #1
	BEQ .Modulus_Check
	JMP .No_Match


.Set_Next_Tile:
	LDA Tile_Uncovered
	CMP #$FF
	BNE .Check_Next_Tile

	LDX Current_Grid_Position
	LDA Board_Tile_Array,X
	ASL ; multiply by 2 because Computer Memory is stored in pairs
	TAX
	LDA Computer_Memory_Bank,X
	STA rnd_end
	JMP .Modulus_Check

.Check_Next_Tile:
	LDX Current_Grid_Position
	LDA Board_Tile_Array,X
	ASL ; multiply by 2 because Computer Memory is stored in pairs
	TAX
	INX
	LDA Computer_Memory_Bank,X
	STA rnd_end

	CMP Current_Grid_Position
	BNE .Modulus_Check
	DEX
	LDA Computer_Memory_Bank,X
	STA rnd_end
	JMP .Modulus_Check

.No_Match:
	LDA #0
	STA rnd_start

	LDA Tiles_Still_Uncovered_Count
	STA rnd_end

	JSR Get_Random_Number

	LDX rnd_end
	LDA Tiles_Still_Uncovered_Array,X
	STA rnd_end

	CMP Current_Grid_Position
	BEQ .No_Match

.Modulus_Check:
	; Modulus of Required Position (Horizontal)
	LDA rnd_end

	SEC
Calculate_Modulus_Of_Required_Position:
	SBC Board_Width
	BPL Calculate_Modulus_Of_Required_Position

	CLC
	ADC Board_Width

.Save_Modulus_Required_Position
	STA .Modulus_Of_Required_Position

.Horizontal_Check
	LDY #$FF
	JSR Delay

	LDA Current_Grid_Position

	SEC
Calculate_Modulus_Of_Current_Position:
	SBC Board_Width
	BPL Calculate_Modulus_Of_Current_Position

	CLC
	ADC Board_Width

.Check_Matching_Horizontal_Position
	STA .Modulus_Of_Current_Position

	CMP .Modulus_Of_Required_Position
	BEQ .Vertical_Check

	BCC .Increase_Horizontal_Offset

.Decrease_Horizontal_Offset:
	LDA #$FF
	JMP .Move_Cursor

.Increase_Horizontal_Offset:
	LDA #1

.Move_Cursor:
	STA Cursor_Offset

	JSR Move_Cursor_Continue
	JMP .Horizontal_Check

.Vertical_Check:
	LDA Current_Grid_Position
	CMP rnd_end
	BNE .Not_The_Same_Position
	JMP Check_Selection

.Not_The_Same_Position:
	BCC .Increase_Vertical_Offset

.Decrease_Vertical_Offset:
	SEC
	LDA #0
	SBC Board_Width
	STA Cursor_Offset
	JMP .Move_Cursor_Vertical

.Increase_Vertical_Offset:
	LDA Board_Width
	STA Cursor_Offset

.Move_Cursor_Vertical:
	JSR Move_Cursor_Continue

	LDY #$FF
	JSR Delay

	JMP .Vertical_Check


.Modulus_Of_Required_Position:	BYTE	0
.Modulus_Of_Current_Position:	BYTE	0

;============================================================================
; Subroutine - Uncover_Tile
; Parameters:
;	- X - Current Tile Index
;
; Affects:
;	- A, X, Y
;
; Used to display the hidden tile graphic to the screen
;============================================================================
	SUBROUTINE

Uncover_Tile:
	JSR Move_To_Tile_Position

	LDX #<Screen_RAM
	LDY #>Screen_RAM
	JSR Calculate_Screen_Destination_Address

	LDX Current_Grid_Position
	LDA Board_Tile_Array,X
	JSR Print_Tile

	LDX #<Colour_RAM
	LDY #>Colour_RAM
	JSR Calculate_Screen_Destination_Address

	LDA #SCN_WHITE
	JSR Print_Tile_Colour

	RTS


;============================================================================
; Subroutine - Cover_Tile
; Parameters:
;
; Affects:
;	- A, X, Y
;
; Used to re-cover the tile after an incorrect guess
;============================================================================
	SUBROUTINE

Cover_Tile:
	JSR Move_To_Tile_Position

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	JSR Calculate_Screen_Destination_Address

	LDA #21 ; covered tile graphic
	JSR Print_Tile

	LDX #<Colour_RAM
	LDY #>Colour_RAM
	JSR Calculate_Screen_Destination_Address

	LDA #SCN_GREY_3
	JSR Print_Tile_Colour

	RTS

;============================================================================
; Subroutine - Update_Tile_Colour
; Parameters:
;	- X - Current Tile Index
;
; Affects:
;	- A, X, Y
;============================================================================
	SUBROUTINE

Update_Tile_Colour:
	JSR Move_To_Tile_Position

	LDX #<Colour_RAM
	LDY #>Colour_RAM
	JSR Calculate_Screen_Destination_Address

	LDA #SCN_LIGHT_RED

	LDX Current_Player
	CPX #2
	BEQ .Print_Tile

	LDA #SCN_LIGHT_GREEN

.Print_Tile
	JSR Print_Tile_Colour
	RTS

;============================================================================
; Subroutine - Move_To_Tile_Position
; Parameters:
;	- X - Current Tile Index
;
; Affects:
;	- A, X, Y
; 
; Parameters:
;
; Updates the Cursor position to the actual tile position
; (which is offset by 1 in X and Y from cursor frame position )
;============================================================================
	SUBROUTINE

Move_To_Tile_Position:
	LDX Current_Grid_Position
	JSR Lookup_Screen_Location

	INC X_Position
	INC Y_Position

	RTS


;============================================================================
; Subroutine - Calculate_Screen_Destination_Address
;
; Parameters:
;	- X - The Base address for either the Screen RAM or the Colour RAM (lo)
;	- Y - The Base address high byte
;
; Sets Start_Destination_Location to the memory offset
; as specified by the cursor location in X_Position and Y_Position
;============================================================================
	SUBROUTINE

Calculate_Screen_Destination_Address:
	STY Start_Destination_Location + 1
	STX Start_Destination_Location

	LDY #0

.Add_Next_Line:
	CPY Y_Position
	BEQ .Add_X_Position

	INY

	LDA Start_Destination_Location
	CLC
	ADC #40
	STA Start_Destination_Location
	BCC .Add_Next_Line

	INC Start_Destination_Location + 1
	JMP .Add_Next_Line

.Add_X_Position:
	CLC
	ADC X_Position
	STA Start_Destination_Location
	BCC .Return
	INC Start_Destination_Location + 1

.Return
	RTS


;============================================================================
; Subroutine - Print_Tile
; Parameters:
;	- A - The tile index number
;============================================================================
	SUBROUTINE

Print_Tile:
	JSR Calculate_Tile_Start_Address

	LDY #0
	LDA (Start_Lookup_Location),Y
	STA (Start_Destination_Location),Y

	LDY #1
	LDA (Start_Lookup_Location),Y
	STA (Start_Destination_Location),Y

	LDY #2
	LDA (Start_Lookup_Location),Y

	LDY #40
	STA (Start_Destination_Location),Y

	LDY #3
	LDA (Start_Lookup_Location),Y

	LDY #41
	STA (Start_Destination_Location),Y

	RTS

;============================================================================
; Subroutine - Print_Tile_Colour
; Parameters:
;	- A - The tile colour
;============================================================================
	SUBROUTINE

Print_Tile_Colour:
	LDY #0
	STA (Start_Destination_Location),Y

	LDY #1
	STA (Start_Destination_Location),Y

	LDY #40
	STA (Start_Destination_Location),Y

	LDY #41
	STA (Start_Destination_Location),Y

	RTS

;============================================================================
; Subroutine - Calculate_Tile_Start_Address
; Parameters:
;	- A - Tile Array Index
;
; Returns
;	- Start_Lookup_Location
;============================================================================
	SUBROUTINE

Calculate_Tile_Start_Address:
	; multiply index by 4 as
	; each tile is 4 bytes
	ASL
	ASL
	STA .Tile_Index

	LDA #>Tile_Pattern_Array
	STA Start_Lookup_Location + 1

	LDA #<Tile_Pattern_Array
	STA Start_Lookup_Location

	CLC
	ADC .Tile_Index
	STA Start_Lookup_Location
	BCC .Return
	INC Start_Lookup_Location + 1

.Return
	RTS

.Tile_Index:			BYTE	0

;============================================================================
; Subroutine - Calculate_Computer_Probability
; Parameters:
;============================================================================
	SUBROUTINE

Calculate_Computer_Probability:
	; REM Comptuer Probability Check
    ; RD = RND(1)
    ; RM% = 0

	LDA #0
	STA rnd_start

	LDA #99
	STA rnd_end

	JSR Get_Random_Number

	LDA #30
	STA .Upper_Difficulty_Bound

	LDA Computer_Difficulty_Level
	CMP #1
	BEQ .Compare_Random_Chance

	LDA #50
	STA .Upper_Difficulty_Bound

	LDA Computer_Difficulty_Level
	CMP #2
	BEQ .Compare_Random_Chance

	LDA #80
	STA .Upper_Difficulty_Bound

.Compare_Random_Chance:
	LDA .Upper_Difficulty_Bound
	CMP rnd_end
	BCS Store_Into_Computer_Memory_Bank

	RTS

.Upper_Difficulty_Bound:	BYTE	0

;============================================================================
; Subroutine - Store_Into_Computer_Memory_Bank
; Parameters:
;============================================================================
	SUBROUTINE

Store_Into_Computer_Memory_Bank:
	; REM Let the computer remember which tile was uncovered
	LDX Current_Grid_Position
	LDA Board_Tile_Array,X
	CLC
	ASL ; multiply the index by 2 because the computer memory is stored in pairs
	TAX
	LDA Computer_Memory_Bank,X
	CMP #$FF
	BEQ .Store_Computer_Memory
	CMP Current_Grid_Position
	BEQ .Return

	INX
	LDA Computer_Memory_Bank,X
	CMP #$FF
	BNE .Return

.Store_Computer_Memory
	LDA Current_Grid_Position
	STA Computer_Memory_Bank,X

.Return
	RTS

;============================================================================
; Subroutine - End_Game
; Parameters:
;============================================================================
	SUBROUTINE

End_Game:
	JSR Clear_Cursor_Location
	JSR Print_End_Box

	LDY #$FF
	JSR Delay

	JSR Play_Win_Jingle

	LDY #$FF
	JSR Delay
	JSR Delay
	JSR Delay
	JSR Delay

	JMP Title_Screen

;============================================================================
; Subroutine - Print_End_Box
; Parameters:
;============================================================================
	SUBROUTINE

Print_End_Box:
	LDA Menu_Player_Count
	CMP #1
	BNE .Check_For_Tie	
	JMP .Single_All_Pairs_Found

.Check_For_Tie:
	LDA Player_Score
	CMP Computer_Score
	BNE .Check_For_Computer_Player
	JMP .Tie

.Check_For_Computer_Player:
	LDA #3
	CMP Menu_Player_Count
	BNE .Not_A_Computer_Player
	JMP .Print_End_Box_Computer

.Not_A_Tie:
.Not_A_Computer_Player:
	LDY #7 ; X Position
	STY X_Position

	LDA Board_Width
	CMP #7
	BNE .Continue_On
	
	LDY #5 ; X Position
	STY X_Position

.Continue_On:
	LDX #10 ; Y Position
	STX Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT
	
	LDX #<Str_End_Box_Top_17
	LDA #>Str_End_Box_Top_17
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_17
	LDA #>Str_End_Box_Space_17
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDA Player_Score
	CMP Computer_Score
	BCS .Print_Player_1_Wins

	LDX #<Str_Player_2_Wins
	LDA #>Str_Player_2_Wins

	JMP .Print_Box_Bottom

.Print_Player_1_Wins:
	LDX #<Str_Player_1_Wins
	LDA #>Str_Player_1_Wins

.Print_Box_Bottom:
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_17
	LDA #>Str_End_Box_Space_17
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Bottom_17
	LDA #>Str_End_Box_Bottom_17
	JSR Print_Text_To_Screen

	RTS

.Single_All_Pairs_Found:
	LDA #6
	STA X_Position

	LDA Board_Width
	CMP #7
	BNE .Single_Top_Box

	LDA #4
	STA X_Position

.Single_Top_Box:
	LDA #10
	STA Y_Position

	LDY X_Position
	LDX Y_Position	
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Top_19
	LDA #>Str_End_Box_Top_19
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position	
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_19
	LDA #>Str_End_Box_Space_19
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position	
	CLC
	JSR PLOT

	LDX #<Str_All_Pairs_Found
	LDA #>Str_All_Pairs_Found
	JSR Print_Text_To_Screen


	INC Y_Position

	LDY X_Position
	LDX Y_Position	
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_19
	LDA #>Str_End_Box_Space_19
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position	
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Bottom_19
	LDA #>Str_End_Box_Bottom_19
	JSR Print_Text_To_Screen

	RTS

.Print_End_Box_Computer:
	LDX #7
	STX X_Position

	LDX Board_Width
	CPX #7
	BNE .End_Box_Computer_Continue

	LDX X_Position
	DEX
	STX X_Position

.End_Box_Computer_Continue:
	LDA #10
	STA Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Top_17
	LDA #>Str_End_Box_Top_17
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_17
	LDA #>Str_End_Box_Space_17
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDA Player_Score
	CMP Computer_Score
	BCS .Print_Player_Wins

	LDX #<Str_Computer_Wins
	LDA #>Str_Computer_Wins

	JMP .Print_Box_Bottom_Computer

.Print_Player_Wins:
	LDX #<Str_Player_Wins
	LDA #>Str_Player_Wins

.Print_Box_Bottom_Computer:
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT


	LDX #<Str_End_Box_Space_17
	LDA #>Str_End_Box_Space_17
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT


	LDX #<Str_End_Box_Bottom_17
	LDA #>Str_End_Box_Bottom_17
	JSR Print_Text_To_Screen

	RTS

.Tie
	LDX #7
	STX X_Position

	LDX Board_Width
	CPX #7
	BNE .Continue_Tie

	LDX X_Position
	DEX
	STX X_Position

.Continue_Tie:
	LDA #10
	STA Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Top_16
	LDA #>Str_End_Box_Top_16
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_16
	LDA #>Str_End_Box_Space_16
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_Its_A_Tie
	LDA #>Str_Its_A_Tie
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Space_16
	LDA #>Str_End_Box_Space_16
	JSR Print_Text_To_Screen

	INC Y_Position

	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_End_Box_Bottom_16
	LDA #>Str_End_Box_Bottom_16
	JSR Print_Text_To_Screen

	RTS

;============================================================================
; Subroutine - Get_Random_Number
; Parameters:
;	rnd_start	-	the lower bound of the random number
;	rnd_end		-	the upper bound of the random number
;
; Same as the BASIC Command:
; INT(RND(1) * (end- start + 1)) + start
;
; Credit to Lovro on StackOverflow
; https://stackoverflow.com/a/60315125
;============================================================================

	SUBROUTINE

Get_Random_Number:
    ; ++end -> increment our end value
    ; (end - start + 1) == ((end + 1) - start)
    inc rnd_end
    bne .Continue
    inc rnd_end + 1

.Continue:
    ; subtract start -> subtract start from end value
    ; (new_end - start) -> new_end = end + 1
    lda rnd_end
    sec
    sbc rnd_start
    sta rnd_end
    lda rnd_end + 1
    sbc rnd_start + 1
    sta rnd_end + 1

    ; ++end-start to FAC
    ; FAC = Floating Point Accumulator
    ; Load our number (new_end - start) and convert it to floating point
    ldy rnd_end
    lda rnd_end + 1
    jsr $B391 ; A(h),Y(L) - FAC

    ; Store our floating point number
    ; temporarily for later arithmatic
    ldx #<rnd_flt
    ldy #>rnd_flt
    jsr $BBD4   ; store FAC to rnd_flt

    ; get actual RND(1)
    lda #$7f
    jsr $E09A

    ; Multiply the FAC by our temporary floating point number
    ; multiply by ++end - start
    lda #<rnd_flt
    ldy #>rnd_flt
    jsr $BA28

    ; to integer
    ; Call INT() function - result in FAC
    jsr $BCCC

    ; FAC to int
    ; Convert the FAC to a real integer that we can use
    jsr $B1BF

    ; Offset random number into range
    ; requested by start and end values
    ; store result in rnd_end(l) and rnd_end + 1 (H) bytes
    lda $65         
    clc
    adc rnd_start
    sta rnd_end
    lda $64
    adc rnd_start + 1
    sta rnd_end + 1

	rts

;============================================================================
; Subroutine - Set_Board_Size_Variables
; Parameters:
;	- none
;
; Affects:
;	- A, X, Z
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Set_Board_Size_Variables:
	; Set Board Sizes
	; For easiness, board height will be 1 less than board width
    ; eg, 5 wide x 4 tall, 6 wide x 5 tall, 7 wide x 6 tall

	; Set Board Height
	LDX Board_Width
	DEX
	STX Board_Height

	; Set board size
	; multiply board width x board height
	LDA #0
	CLC
.Add_Board_Width:
	ADC Board_Width
	DEX
	BNE .Add_Board_Width
	STA Board_Size

	; Set Tiles Required
    ; Matching in pairs so only need half the board size
	CLC
	ROR ; divide by 2
	STA Tiles_Required

	; Set the upper bound of the tiles still uncovered in this game
	; for the computer to randomly pick from
	LDX Board_Size
	DEX
	STX Tiles_Still_Uncovered_Count

	RTS

;============================================================================
; Subroutine - Reset_Computer_Memory_Bank
; Parameters:
;	- none
;
; Affects:
;	- A, X, Z
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Reset_Computer_Memory_Bank:
	LDX #41
	LDA #$FF
.Loop:
	STA Computer_Memory_Bank,X
	DEX
	BPL .Loop

	RTS

;============================================================================
; Subroutine - Initialise_Board_Tile_State
; Parameters:
;	- none
;
; Affects:
;	- A, X, Z
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Initialise_Board_Tile_State:
	LDX #41

.Loop:
	LDA #0
	STA Board_Tile_State_Array,X

	;may not be needed
	LDA #$FF
	STA Board_Tile_Array,X
	;------------------

	; Transfer X, so that the value can be stored
	; as well as for indexing.
	TXA

	; Store the tile in the uncovered array.
	;
	; This is used for the computer to pick randomly from known covered tiles 
	; instead of brute forcing Board_Tile_State_Array
	STA Tiles_Still_Uncovered_Array,X

	; divide by 2 as there are at most, 21 pairs of tiles ((7 x 6) / 2)
	CLC
	ROR
	STA Board_Tile_Array,X

	DEX
	BPL .Loop

	RTS

;============================================================================
; Subroutine - Pick_Tiles_For_Board
; Parameters:
;	- none
;
; Affects:
;	- A, X, Z
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Pick_Tiles_For_Board:
	;reseed, to avoid repeated sequence; RND(0)
	lda #$0
	jsr $E09A

	; Richard Durstenfeld Shuffling algorithm
    ; Based on the Fisher-Yates Algorithm
    ; https://en.wikipedia.org/wiki/Fisher-Yates_shuffle

    ;-- To shuffle an array a of n elements (indices 0..n-1):
    ;for i from 0 to n−2 do
    ;  j - random integer such that i <= j <= n-1
    ;  exchange a[i] and a[j]

	LDX #0

Pick_Tiles_For_Board_Outer_Loop:
	; TODO - Add sound

	STX .Temp_X

	LDA #0
	STA rnd_start

	SEC
	LDA Board_Size
	SBC #1
	SBC .Temp_X
	STA rnd_end

	JSR Get_Random_Number

	CLC
	LDA rnd_end
	ADC .Temp_X

	TAY
	LDA Board_Tile_Array,Y
	STA .Temp_Swap

	LDX .Temp_X

	LDA Board_Tile_Array,X
	STA Board_Tile_Array,Y

	LDA .Temp_Swap
	STA Board_Tile_Array,X

	INX
	STX .Temp_X

	SEC
	LDA Board_Size
	SBC #2
	CMP .Temp_X
	BNE Pick_Tiles_For_Board_Outer_Loop

	RTS

.Temp_X:	BYTE	0
.Temp_Swap:	BYTE	0

;============================================================================
; Subroutine - Print_Text_To_Screen
; Parameters:
;	- A - Start address of text (hi-byte)
;	- X - Start address of text (hi-byte)
;
; Affects:
;	- A, Z
;
; Remarks:
;	Use 0 to acts as string terminator
;
; Used to print text to the screen at the current cursor location
;============================================================================

	SUBROUTINE

Print_Text_To_Screen:
	STX Start_Lookup_Location
	STA Start_Lookup_Location + 1

	; save Y register
	; A and X are set externally, so not our problem
	TYA
	PHA

	; intialize loop
	LDY #0

.Text_Loop
	LDA (Start_Lookup_Location),Y
	
	; if character value is a 0, there's no more text to print
	BEQ .Return
	JSR CHROUT

	INY
	JMP .Text_Loop

.Return
	; restore Y register
	PLA
	TAY

	RTS


;============================================================================
; Subroutine - Print_Empty_Board
; Parameters:
;	none
;
; Affects:
;	- A, Z
;============================================================================

	SUBROUTINE

Print_Empty_Board:
	LDA Board_Width

.Test_Board_Size_5:
	CMP #5
	BEQ .Print_Empty_Board_5

.Test_Board_Size_6:
	CMP #6
	BEQ .Print_Empty_Board_6

	; RTS not needed because the print section
	; will handle the return

.Print_Empty_Board_7:
	LDX #<screen_7x6
	LDY #>screen_7x6

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	LDX #<screen_7x6_color
	LDY #>screen_7x6_color

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Colour_RAM
	LDY #>Colour_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	RTS


.Print_Empty_Board_5:
	LDX #<screen_5x4
	LDY #>screen_5x4

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	LDX #<screen_5x4_color
	LDY #>screen_5x4_color

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Colour_RAM
	LDY #>Colour_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	RTS

.Print_Empty_Board_6:
	LDX #<screen_6x5
	LDY #>screen_6x5

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	LDX #<screen_6x5_color
	LDY #>screen_6x5_color

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Colour_RAM
	LDY #>Colour_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	RTS



;============================================================================
; Subroutine - Copy_Screen_Data
; Parameters:
;	- none
;
; Used to load a screenful of data into screen and colour ram.
;============================================================================
	SUBROUTINE

Copy_Screen_Data:

	LDX #25	; line number
	LDY #39	; horizontal character index

.Load_Screen_Data:
	LDA (Start_Lookup_Location),Y
	STA (Start_Destination_Location),Y

	DEY
	BPL .Load_Screen_Data

	LDY #39	; reset screen index
	

	; set new lookup location
	LDA Start_Lookup_Location
	CLC
	ADC #40
	STA Start_Lookup_Location
	BCC .Continue
	INC Start_Lookup_Location + 1

	; set new destination location
.Continue:
	LDA Start_Destination_Location
	CLC
	ADC #40
	STA Start_Destination_Location
	BCC .Check_If_More_Lines
	INC Start_Destination_Location + 1
	
.Check_If_More_Lines:
	DEX		; increment line number
	BNE .Load_Screen_Data

	RTS


;============================================================================
; Subroutine - Print_Score_Panel
; Parameters:
;	none
;
; Affects:
;	- A, Z
;============================================================================

	SUBROUTINE

Print_Score_Panel:
	; Set Cursor Position
	LDY #31		; X Position
	LDX #4		; Y
	CLC
	JSR PLOT

	LDA #ASC_LIGHT_GREEN
	JSR CHROUT

	LDA Menu_Player_Count
	CMP #2
	BNE .Print_Player

.Print_Player_1
	LDX #<Str_Player_1
	LDA #>Str_Player_1		
	JMP .Continue_Player_1

.Print_Player:
	LDX #<Str_Player
	LDA #>Str_Player	

.Continue_Player_1:
	JSR Print_Text_To_Screen

	LDY #37
	LDX #7

	LDA Player_Score
	CMP #10
	BCC .Print_Player_Score
	DEY

.Print_Player_Score:
	CLC
	JSR PLOT

	LDA #ASC_CYAN
	JSR CHROUT

	LDA #0
	LDX Player_Score
	JSR PRINT_NUMBER


	LDA Menu_Player_Count
	CMP #1
	BNE .Continue
	RTS

.Continue
	; Set Cursor Position
	LDY #31		; X Position
	LDX #12		; Y
	CLC
	JSR PLOT

	LDA #ASC_WHITE
	JSR CHROUT

	LDX #<Str_Matches
	LDA #>Str_Matches		
	JSR Print_Text_To_Screen

	; Set Cursor Position
	LDY #31		; X Position
	LDX #11		; Y
	CLC
	JSR PLOT

	LDA #ASC_LIGHT_RED
	JSR CHROUT

	LDA Menu_Player_Count
	CMP #3
	BEQ .Continue_Print_Computer

	LDX #<Str_Player_2
	LDA #>Str_Player_2
	JMP .Continue_2

.Continue_Print_Computer
	LDX #<Str_Computer
	LDA #>Str_Computer		

.Continue_2
	JSR Print_Text_To_Screen

	LDY #37
	LDX #14

	LDA Computer_Score
	CMP #10
	BCC .Print_Computer_Score
	DEY

.Print_Computer_Score:
	CLC
	JSR PLOT

	LDA #ASC_CYAN
	JSR CHROUT

	LDA #0
	LDX Computer_Score
	JSR PRINT_NUMBER

	RTS



;============================================================================
; Subroutine - Print_Shuffling_Box
; Parameters:
;	- none
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Print_Shuffling_Box:
	RTS

;============================================================================
; Subroutine - Clear_Shuffling_Box
; Parameters:
;	- none
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Clear_Shuffling_Box:
	RTS

;============================================================================
; Subroutine - Print_Covered_Board_Tiles
; Parameters:
;	- none
;
;	Affects:
;	- A
;
; Prints the covered board tiles in the grid, specified by the board width
;============================================================================

	SUBROUTINE

Print_Covered_Board_Tiles:
	LDA Board_Width

	CMP #6
	BEQ .Print_Board_6

	CMP #7
	BEQ	.Print_Board_7

.Print_Board_5
	LDA #4
	STA X_Position

	LDA #3
	STA Y_Position

	LDY #4

.Print_Board_5_Outer_Loop:
	STY .Temp_Y

	LDX #2
	

.Print_Board_5_Inner_Loop:
	STX .Temp_X
	INC Y_Position
	
	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_Board_5
	LDA #>Str_Board_5		
	JSR Print_Text_To_Screen

	LDX .Temp_X
	DEX
	BNE .Print_Board_5_Inner_Loop

	INC Y_Position
	INC Y_Position
	INC Y_Position

	LDY .Temp_Y
	DEY
	BNE .Print_Board_5_Outer_Loop

	RTS

.Print_Board_6
	LDA #4
	STA X_Position

	LDA #3
	STA Y_Position

	LDY #5

.Print_Board_6_Outer_Loop:
	STY .Temp_Y

	LDX #2
	

.Print_Board_6_Inner_Loop:
	STX .Temp_X
	INC Y_Position
	
	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_Board_6
	LDA #>Str_Board_6		
	JSR Print_Text_To_Screen

	LDX .Temp_X
	DEX
	BNE .Print_Board_6_Inner_Loop

	INC Y_Position
	INC Y_Position

	LDY .Temp_Y
	DEY
	BNE .Print_Board_6_Outer_Loop

	RTS

.Print_Board_7
	LDA #5
	STA X_Position

	LDA #3
	STA Y_Position

	LDY #6

.Print_Board_7_Outer_Loop:
	STY .Temp_Y

	LDX #2
	

.Print_Board_7_Inner_Loop:
	STX .Temp_X
	INC Y_Position
	
	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDX #<Str_Board_7
	LDA #>Str_Board_7		
	JSR Print_Text_To_Screen

	LDX .Temp_X
	DEX
	BNE .Print_Board_7_Inner_Loop

	INC Y_Position

	LDY .Temp_Y
	DEY
	BNE .Print_Board_7_Outer_Loop

	RTS

.Temp_X:		BYTE	0
.Temp_Y:		BYTE	0


;============================================================================
; Subroutine - Setup_Tile_Shuffle_Sound
; Parameters:
;
; Affects:
;	- A
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================

	SUBROUTINE

Setup_Tile_Shuffle_Sound:
	; Set High Pulse Width for Voice 1
	LDA #240
	STA SID_Location

	LDA #20
	STA SID_Location + 1

	;Set Attack/Decay for voice 1 (A=4,D=8)
	LDA #72
	STA SID_Location + 5

    ;Set High Cut-off frequency for filter
	LDA #0
	STA SID_Location + 22

    ;Turn on Voice 1 filter
	LDA #1
	STA SID_Location + 23

    ;Set Volume and high pass filter
	LDA #79
	STA SID_Location + 24

	RTS

;============================================================================
; Subroutine - Play_Cursor_Positive_Sound
; Parameters:
;
; Affects:
;	- A
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Cursor_Positive_Sound:
	; Set Frequency
	LDA #12
	STA SID_Location

	LDA #71
	STA SID_Location + 1

	JSR Play_Cursor_Sound

	RTS

;============================================================================
; Subroutine - Play_Cursor_Negative_Sound
; Parameters:
;
; Affects:
;	- A
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Cursor_Negative_Sound:
	; Set Frequency
	LDA #181
	STA SID_Location

	LDA #23
	STA SID_Location + 1

	JSR Play_Cursor_Sound
	
	RTS

;============================================================================
; Subroutine - Play_Cursor_Negative_Sound
; Parameters:
;
; Affects:
;	- A
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Cursor_Select_Sound:
	; Set Frequency
    ; Set High Pulse Width for Voice 1

	LDA #240
	STA SID_Location

	LDA #20
	STA SID_Location + 1

	; Set Attack/Decay for voice 1 (A=4,D=8)
	LDA #34
	STA SID_Location + 5

    ; Disable High Cut-off frequency for filter
	LDA #0
	STA SID_Location + 22

    ; Turn off Voice 1 filter
    STA SID_Location + 23

    ; Set Volume
	LDA #$0F
	STA SID_Location + 24

    ; Start Sound
	LDA #$81
	STA SID_Location + 4
    
	LDY #$80
    JSR Delay
    
    ;REM Stop Sound
	LDA #$80
	STA SID_Location + 4

	; Set Volume
    LDA #0
	STA SID_Location + 24	

	RTS

;============================================================================
; Subroutine - Play_Player_1_Match_Sound
; Parameters:
;
; Affects:
;	- A
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Player_1_Match_Sound:
    ; Set Frequency
	LDX #0
	LDA Win_Jingle,X
	STA SID_Location

	INX
	LDA Win_Jingle,X
	STA SID_Location + 1

    JSR Play_Cursor_Sound

	LDX #6
	LDA Win_Jingle,X
	STA SID_Location

	INX
	LDA Win_Jingle,X
	STA SID_Location + 1

    JSR Play_Cursor_Sound
    
    RTS

;============================================================================
; Subroutine - Play_Player_2_Match_Sound
; Parameters:
;
; Affects:
;	- A
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Player_2_Match_Sound:
	; Set Frequency
	LDX #8
	LDA Win_Jingle,X
	STA SID_Location

	INX
	LDA Win_Jingle,X
	STA SID_Location + 1

    JSR Play_Cursor_Sound

	LDX #14
	LDA Win_Jingle,X
	STA SID_Location

	INX
	LDA Win_Jingle,X
	STA SID_Location + 1

    JSR Play_Cursor_Sound
    
    RTS

;============================================================================
; Subroutine - Play_Win_Jingle
; Parameters:
;
; Affects:
;	- A, X, Y
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Win_Jingle:
	LDA Computer_Score
	CMP Player_Score
	BCS .Computer_Win_Jingle

.Player_Win_Jingle:
	LDX #$FF
	JMP .Outer_Loop

.Computer_Win_Jingle:
	LDX #7

.Outer_Loop:
	LDY #0	

.Loop:
	TYA
	PHA ; temp store loop count (Y register)

	INX
	LDA Win_Jingle,X
	STA SID_Location

	INX
	LDA Win_Jingle,X
	STA SID_Location + 1

	TXA
	PHA ; temp store X register

	JSR Play_Cursor_Sound

	PLA
	TAX ; restore X register

	PLA
	TAY ; restore Y register

	INY
	CPY #4
	BNE .Loop

	RTS



;============================================================================
; Subroutine - Play_Cursor_Sound
; Parameters:
;
; Affects:
;	- A, X, Y
;
; Remarks:
;	Use 0 to acts as string terminator
;============================================================================
	SUBROUTINE

Play_Cursor_Sound:
    ; Set Attack/Decay for voice 1 (A=4,D=8)
    LDA #34
	STA SID_Location + 5	

    ; Disable High Cut-off frequency for filter
    LDA #0
	STA SID_Location + 22	

    ; Turn off Voice 1 filter
    STA SID_Location + 23

    ; Set Volume
    LDA #$0F
	STA SID_Location + 24	

    ;REM Start Sound
    LDA #$21
	STA SID_Location + 4
	
	LDY #$80
    JSR Delay
    
    ; Stop Sound
    LDA $20
	STA SID_Location + 4

	; Set Volume
    LDA #0
	STA SID_Location + 24

    RTS

;============================================================================
; Subroutine - Lookup_Screen_Location
; Parameters:
;	- X - Current Tile Index
;
; Affects:
;	- A
;
; Sets:
;	- X_Position
;	- Y_Position
;
; Used to calculate the screen co-ordinates for a given tile location
;============================================================================

	SUBROUTINE

Lookup_Screen_Location:
	LDA Board_Width

	CMP #6
	BEQ .Return_XY_6

	CMP #7
	BEQ .Return_XY_7

.Return_XY_5:
	LDA screen_5x4_xpos,X
	STA X_Position

	LDA screen_5x4_ypos,X
	STA Y_Position

	RTS

.Return_XY_6:
	LDA screen_6x5_xpos,X
	STA X_Position

	LDA screen_6x5_ypos,X
	STA Y_Position

	RTS

.Return_XY_7:
	LDA screen_7x6_xpos,X
	STA X_Position

	LDA screen_7x6_ypos,X
	STA Y_Position

	RTS

;============================================================================
; Subroutine - Highlight_Cursor_Location
; Parameters:
;	- Current_Grid_Position
;
; Affects:
;	- A, Z
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Highlight_Cursor_Location:
	LDX Current_Grid_Position

	; Set Highlight Colour for later
	LDA #ASC_LIGHT_GREEN
	STA .Highlight_Colour

	LDA Current_Player
	CMP #2
	BNE .Check_Board_Width
	LDA #ASC_LIGHT_RED
	STA .Highlight_Colour

.Check_Board_Width:
	LDA #6
	CMP Board_Width
	BEQ .Highlight_6x5

	LDA #7
	CMP Board_Width
	BEQ .Highlight_7x6

.Highlight_5x4:
	LDA screen_5x4_xpos,X
	STA X_Position

	LDA screen_5x4_ypos,X
	STA Y_Position

	JMP .Plot_Cursor

.Highlight_6x5:
	LDA screen_6x5_xpos,X
	STA X_Position

	LDA screen_6x5_ypos,X
	STA Y_Position

	JMP .Plot_Cursor

.Highlight_7x6:
	LDA screen_7x6_xpos,X
	STA X_Position

	LDA screen_7x6_ypos,X
	STA Y_Position

.Plot_Cursor:
	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDA .Highlight_Colour
	JSR CHROUT

	LDA #176
	JSR CHROUT

	LDA #32
	JSR CHROUT
	JSR CHROUT

	LDA #174
	JSR CHROUT

	INX
	INX
	INX

	CLC
	JSR PLOT

	LDA .Highlight_Colour
	JSR CHROUT

	LDA #173
	JSR CHROUT

	LDA #32
	JSR CHROUT
	JSR CHROUT

	LDA #189
	JSR CHROUT

	RTS

.Highlight_Colour:	BYTE	0

;============================================================================
; Subroutine - Clear_Cursor_Location
; Parameters:
;	- Current_Grid_Position
;
; Used to pre-popluate board variables when the size of the board changes
;============================================================================

	SUBROUTINE

Clear_Cursor_Location:
	LDX Current_Grid_Position

.Check_Board_Width:
	LDA #6
	CMP Board_Width
	BEQ .Clear_Highlight_6x5

	LDA #7
	CMP Board_Width
	BEQ .Clear_Highlight_7x6

.Clear_Highlight_5x4:
	LDA screen_5x4_xpos,X
	STA X_Position

	LDA screen_5x4_ypos,X
	STA Y_Position

	JMP .Plot_Cursor

.Clear_Highlight_6x5:
	LDA screen_6x5_xpos,X
	STA X_Position

	LDA screen_6x5_ypos,X
	STA Y_Position

	JMP .Plot_Cursor

.Clear_Highlight_7x6:
	LDA screen_7x6_xpos,X
	STA X_Position

	LDA screen_7x6_ypos,X
	STA Y_Position

.Plot_Cursor:
	LDY X_Position
	LDX Y_Position
	CLC
	JSR PLOT

	LDA #32
	JSR CHROUT
	JSR CHROUT
	JSR CHROUT
	JSR CHROUT

	INX
	INX
	INX

	CLC
	JSR PLOT

	LDA #32
	JSR CHROUT
	JSR CHROUT
	JSR CHROUT
	JSR CHROUT

	RTS

;============================================================================
; Subroutine - Delay
; Parameters:
;	Y - Loop iteration delay
;============================================================================
	SUBROUTINE

Delay:
	LDX #$FF
.Inner_Loop:
	DEX
	BNE .Inner_Loop
	
	DEY
	BNE Delay

	RTS

;============================================================================
; Subroutine - Print_Title_Screen
; Parameters:
;	none
;
; Affects:
;	- A, Z
;============================================================================
	SUBROUTINE

Print_Title_Screen:
	LDX #<title_screen_chars
	LDY #>title_screen_chars

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	LDX #<title_screen_colour
	LDY #>title_screen_colour

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Colour_RAM
	LDY #>Colour_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	RTS

;============================================================================
; Subroutine - Print_Menu_Screen
; Parameters:
;	none
;
; Affects:
;	- A, Z
;============================================================================
	SUBROUTINE

Print_Menu_Screen:
	LDX #<menu_screen_chars
	LDY #>menu_screen_chars

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	LDX #<menu_screen_colours
	LDY #>menu_screen_colours

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Colour_RAM
	LDY #>Colour_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

	RTS


;============================================================================
; Routine - Menu_Screen
; Parameters:
;============================================================================
	SUBROUTINE
	
Menu_Screen:
	JSR Print_Menu_Screen
	JSR Print_Board_Size_Option
	JSR Print_Players_Option
	JSR Print_CPU_Difficulty

.Wait:
	JSR GETIN

	; compare RETURN key
	CMP #13
	BNE .Check_F1_Key
	JMP Restart_Game

.Check_F1_Key:
	CMP #133 ; F1 Key
	BEQ .Set_Board_Size

.Check_F3_Key:
	CMP #134 ; F3 Key
	BEQ .Set_Player_Count

.Check_F5_Key:
	CMP #135 ; F5 Key
	BEQ .Set_CPU_Difficulty

.Check_Instuctions_Key:
	CMP #"I"
	BNE .Check_Credit_Key
	JSR Print_Instructions_Screen
	JMP Title_Screen

.Check_Credit_Key:
	CMP #"C"
	BNE .Wait

	JSR Print_Credits_Screen
	JMP Title_Screen

.Set_Board_Size:
	LDA Board_Width
	CMP #7
	BCS .Reset_Board_Size_To_5
	INC Board_Width
	JMP .Set_Board_Size_Continue

.Reset_Board_Size_To_5:
	LDA #5
	STA Board_Width

.Set_Board_Size_Continue:
	JSR Set_Board_Size_Variables
	JSR Print_Board_Size_Option
	JMP .Wait

.Set_Player_Count:
	LDA Menu_Player_Count
	CMP #3
	BCS .Reset_Player_Count_To_1
	INC Menu_Player_Count
	JMP .Set_Player_Count_Continue

.Reset_Player_Count_To_1:
	LDA #1
	STA Menu_Player_Count

.Set_Player_Count_Continue:
	JSR Print_Players_Option
	JSR Print_CPU_Difficulty
	JMP .Wait

.Set_CPU_Difficulty:
	LDA Menu_Player_Count
	CMP #3
	BEQ .Update_CPU_Difficulty
	JMP .Wait

.Update_CPU_Difficulty:
	LDA Computer_Difficulty_Level
	CMP #3
	BCS .Reset_Computer_Difficulty_To_Low
	INC Computer_Difficulty_Level
	JMP .Set_CPU_Difficulty_Continue

.Reset_Computer_Difficulty_To_Low:
	LDA #1
	STA Computer_Difficulty_Level

.Set_CPU_Difficulty_Continue:
	JSR Print_CPU_Difficulty
	JMP .Wait


;============================================================================
; Subroutine - Print_Board_Size_Option
; Parameters:
;============================================================================
	SUBROUTINE

Print_Board_Size_Option:
	LDY #4
	LDX #14
	CLC
	JSR PLOT

	LDX #<Str_Menu_Board_Size_Text
	LDA #>Str_Menu_Board_Size_Text		
	JSR Print_Text_To_Screen

	LDA Board_Width

	CMP #6
	BEQ .Print_Option_6

	CMP #7
	BEQ .Print_Option_7

.Print_Option_5:
	LDX #<Str_Menu_Board_Size_5
	LDA #>Str_Menu_Board_Size_5

	JMP .Print_Text

.Print_Option_6:
	LDX #<Str_Menu_Board_Size_6
	LDA #>Str_Menu_Board_Size_6

	JMP .Print_Text

.Print_Option_7:
	LDX #<Str_Menu_Board_Size_7
	LDA #>Str_Menu_Board_Size_7	

.Print_Text
	JSR Print_Text_To_Screen
	
	RTS

;============================================================================
; Subroutine - Print_Players_Option
; Parameters:
;============================================================================
	SUBROUTINE

Print_Players_Option:
	LDY #4
	LDX #16
	CLC
	JSR PLOT

	LDX #<Str_Menu_Players_Text
	LDA #>Str_Menu_Players_Text		
	JSR Print_Text_To_Screen

	LDA Menu_Player_Count

	CMP #2
	BEQ .Print_Option_2

	CMP #3
	BEQ .Print_Option_3

.Print_Option_1:
	LDX #<Str_Menu_Players_1
	LDA #>Str_Menu_Players_1

	JMP .Print_Text

.Print_Option_2:
	LDX #<Str_Menu_Players_2
	LDA #>Str_Menu_Players_2

	JMP .Print_Text

.Print_Option_3:
	LDX #<Str_Menu_Players_3
	LDA #>Str_Menu_Players_3	

.Print_Text
	JSR Print_Text_To_Screen
	
	RTS


;============================================================================
; Subroutine - Print_CPU_Difficulty
; Parameters:
;============================================================================
	SUBROUTINE

Print_CPU_Difficulty:
	LDY #4
	LDX #18
	CLC
	JSR PLOT

	LDA Menu_Player_Count
	CMP #3
	BNE .Print_Empty_String

	LDX #<Str_Menu_CPU_Diff_Text
	LDA #>Str_Menu_CPU_Diff_Text		
	JSR Print_Text_To_Screen

	LDA Computer_Difficulty_Level

	CMP #2
	BEQ .Print_Option_Mid

	CMP #3
	BEQ .Print_Option_Hi

.Print_Option_Low:
	LDX #<Str_Menu_CPU_Diff_Low
	LDA #>Str_Menu_CPU_Diff_Low

	JMP .Print_Text

.Print_Option_Mid:
	LDX #<Str_Menu_CPU_Diff_Mid
	LDA #>Str_Menu_CPU_Diff_Mid

	JMP .Print_Text

.Print_Option_Hi:
	LDX #<Str_Menu_CPU_Diff_Hi
	LDA #>Str_Menu_CPU_Diff_Hi

	JMP .Print_Text

.Print_Empty_String:
	LDX #<Str_Menu_CPU_Diff_Empty
	LDA #>Str_Menu_CPU_Diff_Empty

	JMP .Print_Text

.Print_Text
	JSR Print_Text_To_Screen
	
	RTS

;============================================================================
; Subroutine - Print_Instructions_Screen
; Parameters:
;============================================================================
	SUBROUTINE

Print_Instructions_Screen:
	LDX #<instructions_screen_1
	LDY #>instructions_screen_1

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data
	JSR Set_Screen_Text_Colour_To_White
	JSR Highlight_Memory_Game_In_Menu_Screens

.Wait_Key:
	; Get a character from the input - BASIC equivalent: GET A$
	; Wait for a key to be pressed
	JSR GETIN
	CMP #0
	BEQ .Wait_Key

	LDX #<instructions_screen_2
	LDY #>instructions_screen_2

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data

.Wait_Key_2:
	; Get a character from the input - BASIC equivalent: GET A$
	; Wait for a key to be pressed
	JSR GETIN
	CMP #0
	BEQ .Wait_Key_2

	RTS


;============================================================================
; Subroutine - Set_Screen_Text_Colour_To_White
; Parameters:
;============================================================================
	SUBROUTINE

Set_Screen_Text_Colour_To_White:
	LDX #<Colour_RAM
	LDY #>Colour_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	LDX #25	; line number
	LDY #39	; horizontal character index

.Load_Screen_Data:
	LDA #1
	STA (Start_Destination_Location),Y

	DEY
	BPL .Load_Screen_Data

	LDY #39	; reset screen index

	; set new destination location
.Continue:
	LDA Start_Destination_Location
	CLC
	ADC #40
	STA Start_Destination_Location
	BCC .Check_If_More_Lines
	INC Start_Destination_Location + 1
	
.Check_If_More_Lines:
	DEX		; increment line number
	BNE .Load_Screen_Data

	RTS

;============================================================================
; Subroutine - Print_Credits_Screen
; Parameters:
;============================================================================
	SUBROUTINE

Print_Credits_Screen:
	LDX #<credits_screen
	LDY #>credits_screen

	STX Start_Lookup_Location
	STY Start_Lookup_Location + 1

	LDX #<Screen_RAM
	LDY #>Screen_RAM

	STX Start_Destination_Location
	STY Start_Destination_Location + 1

	JSR Copy_Screen_Data
	JSR Set_Screen_Text_Colour_To_White
	JSR Highlight_Memory_Game_In_Menu_Screens

	LDA #SCN_LIGHT_GREEN

.Retro_Programmers_Inside:
	LDY #$F1
	STY Start_Destination_Location

	LDY #>Colour_RAM
	STY Start_Destination_Location + 1

	LDY #24	
.Retro_Programmers_Inside_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .Retro_Programmers_Inside_Loop

.RPI_1:
	LDY #$0B
	STY Start_Destination_Location

	LDY #$D9
	STY Start_Destination_Location + 1

	LDY #3
.RPI_1_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .RPI_1_Loop

.The_Polar_Pop:
	LDY #$59
	STY Start_Destination_Location

	LDY #$DA
	STY Start_Destination_Location + 1

	LDY #13
.The_Polar_Pop_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .The_Polar_Pop_Loop

.DeadSheppy:
	LDY #$6B
	STY Start_Destination_Location

	LDY #$DA
	STY Start_Destination_Location + 1

	LDY #10
.DeadSheppy_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .DeadSheppy_Loop

.RPI_2:
	LDY #$12
	STY Start_Destination_Location

	LDY #$DB
	STY Start_Destination_Location + 1

	LDY #3
.RPI_2_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .RPI_2_Loop


	LDA #SCN_YELLOW

.Phaze101_1:
	LDY #$19
	STY Start_Destination_Location

	LDY #$D9
	STY Start_Destination_Location + 1

	LDY #8	
.Phaze101_1_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .Phaze101_1_Loop

.Phaze101_2:
	LDY #$21
	STY Start_Destination_Location

	LDY #$DB
	STY Start_Destination_Location + 1

	LDY #8
.Phaze101_2_Loop:
	STA (Start_Destination_Location),Y
	DEY
	BNE .Phaze101_2_Loop




.Wait_Key:
	; Get a character from the input - BASIC equivalent: GET A$
	; Wait for a key to be pressed
	JSR GETIN
	CMP #0
	BEQ .Wait_Key

	RTS

;============================================================================
; Subroutine - Highlight_Memory_Game_In_Menu_Screens
; Parameters:
;============================================================================
	SUBROUTINE

Highlight_Memory_Game_In_Menu_Screens:
.Green_Text:
	LDA #$51
	STA Start_Destination_Location

	LDA #>Colour_RAM
	STA Start_Destination_Location + 1

	LDY #7
	LDA #SCN_LIGHT_GREEN
.Set_Green_Text:
	STA (Start_Destination_Location),Y
	DEY
	BNE .Set_Green_Text

.Red_Text:
	LDA #$58
	STA Start_Destination_Location

	LDY #4
	LDA #SCN_LIGHT_RED
.Set_Red_Text:
	STA (Start_Destination_Location),Y
	DEY
	BNE .Set_Red_Text

	RTS
	

;============================================================================
; Constants
;============================================================================

; Addresses - LDA Symbol
Keyboard_Buffer_Size			=	$00C6 ; NDX Kernal
Maximum_Keyboard_Buffer_Size	=	$0289
Screen_RAM						=	$0400
PRINT_NUMBER					=	$BDCD
SID_Location					=	$D400
Colour_RAM						=	$D800
Joystick_2						=	$DC00
Joystick_1						=	$DC01
Interrupt_Control_and_Status	=	$DC0D
SCNKEY							=	$FF9F
CHROUT							=	$FFD2
CHRIN							=	$FFCF
GETIN							=	$FFE4
PLOT							=	$FFF0

; Values - LDA #Symbol
ASC_WHITE						=	5
ASC_LIGHT_RED					=	150
ASC_LIGHT_GREEN					=	153
ASC_GREY_3						=	155
ASC_CYAN						=	159

SCN_WHITE						=	$01
SCN_CYAN						=	$03
SCN_YELLOW						=	$07
SCN_LIGHT_RED					=	$0A
SCN_LIGHT_GREEN					=	$0D
SCN_GREY_3						=	$0F



;============================================================================
; Variables
;============================================================================

rnd_flt:    					BYTE    0, 0, 0, 0, 0
rnd_start:						WORD	0
rnd_end:						WORD	0

Board_Tile_Array:				DS 42,$FF
Board_Tile_State_Array:			DS 42
Board_Width:					BYTE	0
Board_Height:					BYTE	0
Board_Size:						BYTE	0
Tiles_Required:					BYTE	0
Tiles_Still_Uncovered_Array:	DS 42
Tiles_Still_Uncovered_Count:	BYTE	0
Tile_Uncovered:					BYTE	$FF

Computer_Memory_Bank:			DS 42

; Computer Difficulty Level
; 1 = Low / Easy, 2 - Mid / Medium, 3 = Hi / Hard
Computer_Difficulty_Level:		BYTE	1
Computer_Aware_Of_Tile:			BYTE	0

; Menu Player Count
; 1 = Single Player, 2 = 2 Human Players, 3 = Player vs CPU
Menu_Player_Count:				BYTE	1

Current_Grid_Position:			BYTE	0
Cursor_Offset:					BYTE	0

Player_Score:					BYTE	0
Computer_Score:					BYTE	0
Current_Player:					BYTE	1

Win_Jingle:						BYTE	134, 35, 223, 39, 193, 44, 107, 47
								BYTE	195, 17, 239, 19, 96, 22, 181, 23

Tile_Pattern_Array:
	; Data in screen code values (Appendix B)
	BYTE	233, 223, 95, 105
	BYTE	122, 76, 80, 79
    BYTE	79, 80, 77, 78
    BYTE	86, 86, 86, 86
	BYTE	204, 250, 207, 208

    BYTE	112, 73, 81, 81
    BYTE	85, 73, 107, 115
    BYTE	107, 115, 107, 115
    BYTE	91, 110, 109, 91
    BYTE 	78, 77, 78, 77

    BYTE	65, 83, 90, 88
    BYTE	250, 204, 208, 207
    BYTE	233, 223, 118, 117
    BYTE	214, 214, 214, 214
    BYTE	241, 241, 242, 242
    BYTE	236, 251, 252, 254

    BYTE	77, 78, 78, 77
    BYTE	91, 110, 125, 109
    BYTE	121, 223, 120, 105
    BYTE	77, 78, 77, 78
    BYTE	87, 87, 74, 75
	
	; tile covered pattern
    BYTE	102, 102, 102, 102

;============================================================================
; Strings - ASCII
;============================================================================
Str_Clr_Home:				BYTE	19, 147, 0
Str_Player_1:				BYTE	"PLAYER 1", 0
Str_Player:					BYTE	"  PLAYER", 0
Str_Player_2				BYTE	"PLAYER 2", 0
Str_Computer:				BYTE	"COMPUTER", 0
Str_Matches:				BYTE	" MATCHES", 0
Str_Board_5:				BYTE	#ASC_GREY_3, 166, 166, 32, 32, 32, 166, 166, 32, 32, 32, 166, 166, 32, 32, 32, 166, 166, 32, 32, 32, 166, 166, 0
Str_Board_6:				BYTE	#ASC_GREY_3, 166, 166, 32, 32, 166, 166, 32, 32, 166, 166, 32, 32, 166, 166, 32, 32, 166, 166, 32, 32, 166, 166, 0
Str_Board_7:				BYTE	#ASC_GREY_3, 166, 166, 32, 166, 166, 32, 166, 166, 32, 166, 166, 32, 166, 166, 32, 166, 166, 32, 166, 166, 0
Str_Menu_Board_Size_Text:	BYTE	#ASC_WHITE, "BOARD SIZE     (F1) : ", 0
Str_Menu_Board_Size_5:		BYTE	18, 53, 146, 32, 32, 54, 32, 32, 55, 0
Str_Menu_Board_Size_6:		BYTE	53, 32, 32, 18, 54, 146, 32, 32, 55, 0
Str_Menu_Board_Size_7:		BYTE	53, 32, 32, 54, 32, 32, 18, 55, 146, 0
Str_Menu_Players_Text:		BYTE	#ASC_WHITE, "PLAYERS        (F3) : ", 0
Str_Menu_Players_1:			BYTE	18, "1", 146, "  2  1VCPU", 0
Str_Menu_Players_2:			BYTE	"1  ", 18, "2", 146, "  1VCPU", 0
Str_Menu_Players_3:			BYTE	"1  2  ", 18, "1VCPU", 146, 0
Str_Menu_CPU_Diff_Text:		BYTE	#ASC_WHITE, "CPU DIFFICULTY (F5) : ", 0
Str_Menu_CPU_Diff_Low:		BYTE	18, "LOW", 146, "  MID  HI", 0
Str_Menu_CPU_Diff_Mid:		BYTE	"LOW  ", 18, "MID", 146, "  HI", 0
Str_Menu_CPU_Diff_Hi:		BYTE	"LOW  MID  ", 18, "HI", 146, 0
Str_Menu_CPU_Diff_Empty:	BYTE	"                                                   ", 0
Str_End_Box_Top_16:			BYTE	#ASC_WHITE, 176, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 174, 0
Str_End_Box_Space_16:		BYTE	#ASC_WHITE, 125, "              ", 125, 0
Str_End_Box_Bottom_16:		BYTE	#ASC_WHITE, 173, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 189, 0
Str_End_Box_Top_17:			BYTE	#ASC_WHITE, 176, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 174, 0
Str_End_Box_Space_17:		BYTE	#ASC_WHITE, 125, "               ", 125, 0
Str_End_Box_Bottom_17:		BYTE	#ASC_WHITE, 173, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 189, 0
Str_End_Box_Top_19:			BYTE	#ASC_WHITE, 176, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 174, 0
Str_End_Box_Space_19:		BYTE	#ASC_WHITE, 125, "                 ", 125, 0
Str_End_Box_Bottom_19:		BYTE	#ASC_WHITE, 173, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 189, 0

Str_Player_1_Wins:			BYTE	#ASC_WHITE, 125, #ASC_LIGHT_GREEN, " PLAYER 1 ", #ASC_WHITE, "WINS ", 125, 0
Str_Player_2_Wins:			BYTE	#ASC_WHITE, 125, #ASC_LIGHT_RED, " PLAYER 2 ", #ASC_WHITE, "WINS ", 125, 0
Str_Player_Wins:			BYTE	#ASC_WHITE, 125, #ASC_LIGHT_GREEN, "  PLAYER  ", #ASC_WHITE, "WINS ", 125, 0
Str_Computer_Wins:			BYTE	#ASC_WHITE, 125, #ASC_LIGHT_RED, " COMPUTER ", #ASC_WHITE, "WINS ", 125, 0
Str_All_Pairs_Found:		BYTE	#ASC_WHITE, 125, " ALL PAIRS FOUND ", 125, 0
Str_Its_A_Tie:				BYTE	#ASC_WHITE, 125, "  IT'S A TIE  ", 125, 0

;============================================================================
; Screen Data
;============================================================================

	INCLUDE "5x4.asm"
	INCLUDE "6x5.asm"
	INCLUDE "7x6.asm"
	INCLUDE "title-screen.asm"
	INCLUDE "menu-screen.asm"
	INCLUDE "instructions-screens.asm"
	INCLUDE "credits-screen.asm"

Last_Byte:					BYTE	$FF


;============================================================================
; Zero Page
;============================================================================
	RORG		$000B
X_Position:		BYTE	0
Y_Position:		BYTE	0
	REND

	RORG		$00FB
Start_Lookup_Location:			WORD	0
Start_Destination_Location:		WORD	0
	REND