opt server_output = "./zap_server.luau"
opt client_output = "./zap_client.luau"

type HitData = struct {
	hitX: f32,
	hitY: f32,
	hitZ: f32,
	limbId: u8,
	normX: f32,
	normY: f32,
	normZ: f32,
	materialId: u8,
}

type InventoryItem = struct {
	uuid: string.binary,
	name: string.binary,
	qty: u8,
	enchanted: boolean,
	durability: f32,
}

type Input = struct {
	dt: f64,
	x: f32,
	y: f32,
	jump: u8,
	crouch: u8,
}

event fps_hitreg = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		weaponId: u8,
		timestamp: f64,
		originX: f32,
		originY: f32,
		originZ: f32,
		hitData: HitData[],
	},
}

event input_stream = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: Input[],
}

event save_file_load = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		userId: f64,
		description: string.binary,
		inventory: InventoryItem[],
		stats: map { [string.binary]: u8} ,
		questsCompleted: boolean[],
	},
}

event voxel_chunk = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: buffer,
}