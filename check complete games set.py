import os
import requests
from bs4 import BeautifulSoup

# Set the URL of the Wikipedia page for PlayStation 2 games
url = "https://en.wikipedia.org/wiki/List_of_PlayStation_2_games"

# Set the path to the output file for game names
output_file_path = "playstation_2_games_list.txt"

# Send a request to the URL and get the page HTML content
response = requests.get(url)
html_content = response.text

# Parse the HTML content using BeautifulSoup
soup = BeautifulSoup(html_content, "html.parser")

# Find the table of games on the page
game_table = soup.find("table", class_="wikitable sortable")

# Find all the rows in the game table
game_rows = game_table.find_all("tr")

# Extract the game names from each row
game_names = []
for row in game_rows:
    cells = row.find_all("td")
    if len(cells) > 0:
        game_name = cells[0].text.strip()
        game_names.append(game_name)

# Write the list of game names to a text file
with open(output_file_path, "w") as f:
    for game_name in game_names:
        f.write(game_name + "\n")

print(f"Finished extracting {len(game_names)} game names. The list has been saved to '{output_file_path}'.")

# Set the path to the folder containing game images
game_images_path = "/path/to/game/images/folder"

# Set the path to the text file containing the list of games
games_list_path = output_file_path

# Set the path to the output file for missing games
missing_games_path = "missing_games.txt"

# Read the list of games from the text file
with open(games_list_path, "r") as f:
    games_list = [line.strip() for line in f]

# Check if any of the corresponding image files exist for each game in the list
missing_games = []
for game in games_list:
    game_found = False
    for extension in [".iso", ".bin", ".cue", ".zso"]:
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
