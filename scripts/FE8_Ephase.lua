BattleCheck =1000;
-- emu.speedmode('turbo');
 CharacterStore = 0x0202AB78;
--CharacterStore = 0x0202BCE8;
EnemyStore = CharacterStore + 0x3E * 0x48;
Phase = 0x0202BCFF;
key1 ={};
key1['A']=true;


StartF = movie.framecount();
StatM = {'HpC','Lvl','EXP','Hp','Str','Skl','Spd','Def','Res','Lck','Con', 'X', 'Y'};
OffstC = {0x11, 0x8, 0x9,0x10, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x0E, 0x0F};
EnemyM = {'Alive','HpC','X','Y'};
OffstM = {0x00,0x11,0x0E, 0x0F};

Matcher = {};

newcount = 0;
for checks = 0,0x3D,1 do
	Matcher[checks] = {};
	for i = 1,13,1 do
		Matcher[checks][i] = memory.readbyte(CharacterStore+OffstC[i]+checks*0x48);
	end; 
end;

Estats = {};

for checks = 0,49,1 do
	Matcher[checks+0x3E] = {};	
	if memory.readbyte(EnemyStore +0x11+checks*0x48) > 0 then
		Estats[checks] = {};
		Estats[checks][1] = false;
		Estats[checks][2] = false;
		Matcher[checks+0x3E][1] = true;
		for i = 2,4,1 do
			Matcher[checks+0x3E][i] = memory.readbyte(EnemyStore+OffstM[i]+checks*0x48);
		end;
	else	  	
		Matcher[checks+0x3E][1] = false;
	end;
end;

function nextrng(r1, r2, r3)
	return AND(XOR(SHIFT(r3, 5), SHIFT(r2, -11), SHIFT(r1, -1), SHIFT(r2, 15)),0xFFFF)
end

rngbase=0x03000000;


RNGCheck = savestate.create();
savestate.save(RNGCheck);
Unique = 0;
FClist = {};
outsl = {};
RNGList = {};
TempC = {};
TempE = {};
Pstat = {};
outs2l = {};
OfX = 6; 
OfY = 42;
SX = 5;
SY = 5;

for curord = 0,BattleCheck-1,1 do
   savestate.load(RNGCheck);      
   --RNGLOOP
   for n = 1,curord,1 do
      Rtemp = nextrng(memory.readword(rngbase+4), memory.readword(rngbase+2), memory.readword(rngbase+0));
      memory.writeword(rngbase+4, memory.readword(rngbase+2));
      memory.writeword(rngbase+2, memory.readword(rngbase+0));
      memory.writeword(rngbase+0, Rtemp);      
   end;    
  R = {};
  for Rl = 0,4,2 do
   	R[Rl/2] = memory.readword(rngbase+Rl);
  end;
   --PhaseLoop
   while memory.readbyte(Phase) == 128 do
   		joypad.set(1,key1);
   		key1.start = (not key1.start) or nil;
   	   emu.frameadvance();
   	   gui.text(10,10, string.format('%d of %d done.', curord+1, BattleCheck)); 
   end;
   
	outs = "";

	for checks = 0,0x3D,1 do		
		Pstat[checks] = false;
		for i = 1,11,1 do
			TempC[i] = memory.readbyte(CharacterStore+OffstC[i]+checks*0x48);
		end;
		if Matcher[checks][1] ~= TempC[1] then
	  		outs = outs .. string.format(' %d %dHP', checks,  TempC[1] - Matcher[checks][1]);
	  		if TempC[1] == 0 then
	  			Pstat[checks] = true;
	  			outs  = outs .. '-Dead';
	  		end;
	  	end;	  	 
	   if Matcher[checks][3] ~= TempC[3] then
	    	outs = outs .. string.format(' %d %dXP', checks,  TempC[3] - Matcher[checks][3]);	    	
	  	end;
	  	if Matcher[checks][2] ~= TempC[2] then
	  		outs = outs .. string.format(' %d +%dLvl', checks,  TempC[2] - Matcher[checks][2]);
	  		for j = 4,11,1 do 
	  			outs = outs .. string.format(' %d %d%s', checks,  TempC[j] - Matcher[checks][j],StatM[j]);
	  		end;
	  	end;
	end;
	outs2 = "";	
	for checks = 0,49,1 do		
		for i = 2,4,1 do
			TempC[i] = memory.readbyte(CharacterStore+OffstM[i]+(checks+0x3E)*0x48);
		end;		
		if Matcher[checks+0x3E][1] then 
			Estats[checks][1] = false;
			Estats[checks][2] = false;
			if Matcher[checks+0x3E][2] ~= TempC[2] then
	  			outs2 = outs2 .. string.format(' E%d %dHP', checks,  TempC[2] - Matcher[checks+0x3E][2]);
	  			if TempC[2] == 0 then
	  				Estats[checks][1] = true;
	  				outs2  = outs2 .. '-Dead';	  			
	  			end;	  			  			
	  		end;	  	
	  		if (Matcher[checks+0x3E][3] ~= TempC[3]) or (Matcher[checks+0x3E][4] ~= TempC[4]) then
	  			Estats[checks][2] = true;
	  			Estats[checks][3] = Matcher[checks+0x3E][3];
	  			Estats[checks][4] = Matcher[checks+0x3E][4];
	  			Estats[checks][5] = TempC[3];
	  			Estats[checks][6] = TempC[4];
	  		end;
	  	end;
	end;
	FC = movie.framecount() - StartF;			
	IsUnique = true;
	for n = 1,Unique,1 do
		if FClist[n] == FC and outsl[n] == outs and outs2l[n] == outs2 then
		  IsUnique = false;
		end;
	end;		
	if IsUnique then	
	--	emu.speedmode('normal');
		Unique = Unique + 1;
		FClist[Unique] = FC;
		outsl[Unique] = outs;		
		outs2l[Unique] = outs2;	
		for i = 1,25,1 do			
			gui.drawbox(0,0,320,240,'black','black');			
			gui.text(1,1,"Frames:" .. FC .. "	RNG Distance: " .. curord);
			gui.text(1,10,string.format("RNGx00 = %d   RNGx02 =  %d    RNGx04 = %d", R[0],R[1],R[2]));
			gui.text(1,20,outs);
			gui.text(1,30,outs2);
			gui.drawbox(3,40,238,160, 'black','white');			
			for checks = 0,0x3D,1 do 
			 	if Matcher[checks][1] > 0 then
					if Pstat[checks] then
						X = Matcher[checks][12];
						Y = Matcher[checks][13];
						gui.drawbox(OfX+SX*X,SY*Y+OfY,OfX+SX*X+3,SY*Y+3+OfY,'Green','Blue');		
					else
						X = Matcher[checks][12];
						Y = Matcher[checks][13];
						gui.drawbox(OfX+SX*X,SY*Y+OfY,OfX+SX*X+3,SY*Y+3+OfY,'Green','Green');		
					end;								 				 
			 	end;
			end;
			for checks = 0,49,1 do
				if Matcher[checks+0x3E][1] then 			
					if Estats[checks][2] then
						   	X1 = OfX+SX*Estats[checks][3]+2;
			   				Y1 = OfY+SY*Estats[checks][4]+2;
						   	X2 = OfX+SX*Estats[checks][5]+2;
						   	Y2 = OfY+SY*Estats[checks][6]+2;
			   				gui.drawline(X1,Y1,X2,Y1,'blue');
			   				gui.drawline(X2,Y1,X2,Y2,'blue');
			   				if Estats[checks][1] then
								X = Estats[checks][5];
								Y = Estats[checks][6];
								gui.drawbox(OfX+SX*X,SY*Y+OfY,OfX+SX*X+3,SY*Y+3+OfY,'Red','Blue');						 											
							else						
								X = Estats[checks][5];
								Y = Estats[checks][6];
								gui.drawbox(OfX+SX*X,SY*Y+OfY,OfX+SX*X+3,SY*Y+3+OfY,'Red','Red');							 											
							end;				   				
					else
						if Estats[checks][1] then
							X = Matcher[checks+0x3E][3];
							Y = Matcher[checks+0x3E][4];
							gui.drawbox(OfX+SX*X,SY*Y+OfY,OfX+SX*X+3,SY*Y+3+OfY,'Red','Blue');						 											
						else						
							X = Matcher[checks+0x3E][3];
							Y = Matcher[checks+0x3E][4];							
							gui.drawbox(OfX+SX*X,SY*Y+OfY,OfX+SX*X+3,SY*Y+3+OfY,'Red','Red');							 											
						end;
					end;					
				end;
			end;
			emu.frameadvance();
		end;
	--	emu.speedmode('maximum');
	end;	
end;