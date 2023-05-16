import os

# Set the path to the folder containing game images
game_images_path = "/path/to/game/images/folder"

# Set the path to the text file containing the list of games
games_list_path = "/path/to/games/list.txt"

# Set the path to the output file for missing games
missing_games_path = "/path/to/output/missing_games.txt"

# Set the list of image file extensions to check for
image_extensions = [".iso", ".bin", ".cue", ".zso"]

# Read the list of games from the text file
with open(games_list_path, "r") as f:
    games_list = [line.strip() for line in f]

# Check if any of the corresponding image files exist for each game in the list
missing_games = []
for game in games_list:
    game_found = False
    for extension in image_extensions:
        game_image_path = os.path.join(game_images_path, game + extension)
        if os.path.exists(game_image_path):
            game_found = True
            break
    if not game_found:
        missing_games.append(game)

# Write the list of missing games to a text file
with open(missing_games_path, "w") as f:
    for game in missing_games:
        f.write(game + "\n")

print(f"Finished checking game images. {len(missing_games)} games are missing.")
