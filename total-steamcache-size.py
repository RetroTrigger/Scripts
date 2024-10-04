import requests
from bs4 import BeautifulSoup
import time

API_KEY = 'D3653B5D2C5C2F06E9DE06BCAB7904BF'
STEAM_ID = '76561198063862891'  # SteamID64

# Function to get owned games via Steam API
def get_owned_games(api_key, steam_id):
    url = f"http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={api_key}&steamid={steam_id}&format=json&include_appinfo=1"
    response = requests.get(url).json()
    games = response['response'].get('games', [])
    game_list = [(game['appid'], game.get('name', 'Unknown Game')) for game in games]
    return game_list

# Function to scrape game size from SteamDB
def get_game_size_from_steamdb(appid):
    url = f"https://steamdb.info/app/{appid}/"
    response = requests.get(url)
    
    # Check if we received a valid response
    if response.status_code != 200:
        print(f"Failed to retrieve data for AppID: {appid}")
        return None

    # Print the HTML content for debugging
    print(f"Fetching size for AppID: {appid}")
    print(response.text)  # Debugging - Print the HTML response

    soup = BeautifulSoup(response.text, 'html.parser')

    # Try to find the game size information in the page
    size_element = soup.find("td", {"class": "text-right", "data-sort": True})
    
    if size_element:
        size_text = size_element.text.strip()
        return size_text
    else:
        print(f"Size information not found for AppID: {appid}")
        return None

# Main function to get total library size
def calculate_total_library_size(api_key, steam_id):
    owned_games = get_owned_games(api_key, steam_id)
    total_size_gb = 0

    for appid, name in owned_games:
        print(f"Fetching size for: {name} (AppID: {appid})")
        size = get_game_size_from_steamdb(appid)

        if size:
            print(f"Size for {name}: {size}")
            try:
                # Convert the size to GB (SteamDB may list it in MB or GB)
                if 'MB' in size:
                    size_in_gb = float(size.replace('MB', '').replace(',', '').strip()) / 1024
                elif 'GB' in size:
                    size_in_gb = float(size.replace('GB', '').replace(',', '').strip())
                else:
                    size_in_gb = 0  # Handle unexpected formats

                total_size_gb += size_in_gb
            except ValueError:
                print(f"Error parsing size for {name}")
        else:
            print(f"Could not retrieve size for {name}")

        # Sleep to avoid overloading the server (important for politeness)
        time.sleep(1)

    return total_size_gb

if __name__ == "__main__":
    total_library_size = calculate_total_library_size(API_KEY, STEAM_ID)
    print(f"Total estimated size of Steam library: {total_library_size:.2f} GB")
