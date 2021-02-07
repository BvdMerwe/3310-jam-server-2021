Set server variables in:

On Linux, this is ~/.local/share/godot/app_userdata/[project_name], or ~/.local/share/[custom_name] if use_custom_user_dir is set.

On macOS, this is ~/Library/Application Support/Godot/app_userdata/[project_name], or ~/Library/Application Support/[custom_name] if use_custom_user_dir is set.

On Windows, this is %APPDATA%\Godot\app_userdata\[project_name], or %APPDATA%\[custom_name] if use_custom_user_dir is set. %APPDATA% expands to %USERPROFILE%\AppData\Roaming.

If the project name is empty, user:// falls back to res://.

{
	"END_SCREEN_TIME": 5,
	"GAME_LENGTH": 60,
	"LOBBY_TIME": 3,
	"MAX_PLAYERS": 100,
	"MIN_PLAYERS": 1,
	"SERVER_IP": "127.0.0.1",
	"SERVER_PORT": 6969
}