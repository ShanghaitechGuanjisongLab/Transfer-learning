classdef Flags<uint8
	enumeration
		%% 位旗帜
		%范式

		LightAudio(0b0)
		AudioLight(0b1)

		%目标

		Article(0b00)
		PPT(0b10)

		%脑区

		MOp(0b000)
		RSPd(0b100)

		%位，必须放在最后，否则转字符串会出问题

		Paradigm(0b1)
		Target(0b10)
		BrainRegion(0b100)

		%% 非位旗帜

		Different_cells_not_handled(0)
		Different_cells_replenished(1)
		Different_cells_stripped(2)
	end
	methods
		function obj=or(A,B)
			obj=bitor(A,B);
		end
		function obj=and(A,B)
			obj=bitand(A,B);
		end
	end
end