// Cria (ou atualiza) um perfil e uma coleção de cenas PRÓPRIOS do OBS para gravar o trailer.
// Não altera os perfis/cenas existentes do usuário. Uso: node obs_setup.js <cropL> <cropT> <cropR> <cropB>
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const appdata = process.env.APPDATA;
const base = path.join(appdata, "obs-studio", "basic");
const [cropL, cropT, cropR, cropB] = process.argv.slice(2).map(Number);
const outDir = "C:\\Users\\xpg\\Documents\\roblox-teste\\build\\trailer";
fs.mkdirSync(outDir, { recursive: true });

const title = "C:\\Users\\xpg\\Documents\\roblox-teste\\build\\Test.rbxlx - Roblox Studio";
const encodedTitle = title.replace(/#/g, "#22").replace(/:/g, "#3A");
const windowId = `${encodedTitle}:Qt5159QWindowIcon:RobloxStudioBeta.exe`;

const profileDir = path.join(base, "profiles", "S9Trailer");
fs.mkdirSync(profileDir, { recursive: true });
const hotkey = (key) => JSON.stringify({ bindings: [{ alt: true, control: true, shift: true, key }] });
const ini = [
	"[General]",
	"Name=S9Trailer",
	"",
	"[Video]",
	"BaseCX=1280",
	"BaseCY=720",
	"OutputCX=1280",
	"OutputCY=720",
	"FPSType=1",
	"FPSInt=30",
	"ScaleType=bicubic",
	"",
	"[Output]",
	"Mode=Simple",
	"FilenameFormatting=S9Trailer_%CCYY-%MM-%DD_%hh-%mm-%ss",
	"",
	"[SimpleOutput]",
	"FilePath=C:/Users/xpg/Documents/roblox-teste/build/trailer",
	"RecFormat2=mp4",
	"RecQuality=HQ",
	"RecEncoder=x264",
	"RecAudioEncoder=aac",
	"ABitrate=192",
	"FileNameWithoutSpace=true",
	"RecRB=false",
	"",
	"[Audio]",
	"SampleRate=48000",
	"ChannelSetup=Stereo",
	"",
	"[Hotkeys]",
	`OBSBasic.StartRecording=${hotkey("OBS_KEY_NUM7")}`,
	`OBSBasic.StopRecording=${hotkey("OBS_KEY_NUM8")}`,
	"",
].join("\r\n");
fs.writeFileSync(path.join(profileDir, "basic.ini"), "\ufeff" + ini);

const uuid = () => crypto.randomUUID();
const videoUuid = uuid();
const audioUuid = uuid();
const sceneUuid = uuid();
const common = (extra) =>
	Object.assign(
		{
			prev_ver: 537001986,
			mixers: 0,
			sync: 0,
			flags: 0,
			volume: 1.0,
			balance: 0.5,
			enabled: true,
			muted: false,
			"push-to-mute": false,
			"push-to-mute-delay": 0,
			"push-to-talk": false,
			"push-to-talk-delay": 0,
			hotkeys: {},
			deinterlace_mode: 0,
			deinterlace_field_order: 0,
			monitoring_type: 0,
			private_settings: {},
		},
		extra
	);
const collection = {
	name: "S9Trailer",
	sources: [
		common({
			name: "Studio",
			uuid: videoUuid,
			id: "monitor_capture",
			versioned_id: "monitor_capture",
			// Captura do 2º monitor (a janela do Studio fica maximizada nele); a interface do jogo só
			// aparece na tela composta, não na captura de janela.
			settings: {
				monitor_id: "\\\\?\\DISPLAY#PHL0000#5&36b6257b&1&UID4353#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}",
				capture_cursor: false,
				method: 0,
			},
			mixers: 255,
		}),
		common({
			name: "StudioAudio",
			uuid: audioUuid,
			id: "wasapi_process_output_capture",
			versioned_id: "wasapi_process_output_capture",
			settings: { window: windowId, priority: 0 },
			mixers: 255,
		}),
		common({
			name: "Trailer",
			uuid: sceneUuid,
			id: "scene",
			versioned_id: "scene",
			canvas_uuid: "6c69626f-6273-4c00-9d88-c5136d61696e",
			settings: {
				id_counter: 2,
				custom_size: false,
				items: [
					{
						name: "Studio",
						source_uuid: videoUuid,
						visible: true,
						locked: false,
						rot: 0,
						align: 5,
						bounds_type: 2,
						bounds_align: 0,
						bounds_crop: false,
						crop_left: cropL,
						crop_top: cropT,
						crop_right: cropR,
						crop_bottom: cropB,
						id: 1,
						group_item_backup: false,
						pos: { x: 0, y: 0 },
						scale: { x: 1, y: 1 },
						bounds: { x: 1280, y: 720 },
						scale_filter: "bicubic",
						blend_method: "default",
						blend_type: "normal",
						show_transition: { duration: 0 },
						hide_transition: { duration: 0 },
						private_settings: {},
					},
					{
						name: "StudioAudio",
						source_uuid: audioUuid,
						visible: true,
						locked: false,
						rot: 0,
						align: 5,
						bounds_type: 0,
						bounds_align: 0,
						bounds_crop: false,
						crop_left: 0,
						crop_top: 0,
						crop_right: 0,
						crop_bottom: 0,
						id: 2,
						group_item_backup: false,
						pos: { x: 0, y: 0 },
						scale: { x: 1, y: 1 },
						bounds: { x: 0, y: 0 },
						scale_filter: "disable",
						blend_method: "default",
						blend_type: "normal",
						show_transition: { duration: 0 },
						hide_transition: { duration: 0 },
						private_settings: {},
					},
				],
			},
		}),
	],
	groups: [],
	scene_order: [{ name: "Trailer" }],
	current_scene: "Trailer",
	current_program_scene: "Trailer",
	canvases: [],
	current_transition: "Fade",
	transition_duration: 300,
	transitions: [],
	quick_transitions: [],
	saved_projectors: [],
	preview_locked: false,
	scaling_enabled: false,
	modules: {},
	resolution: { x: 1280, y: 720 },
	version: 2,
};
fs.writeFileSync(path.join(base, "scenes", "S9Trailer.json"), JSON.stringify(collection, null, 4));
console.log("profile + collection written; window =", windowId);
