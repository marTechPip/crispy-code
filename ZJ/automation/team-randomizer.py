import random

# List of players
players = ["Alice", "Ben", "Eileen", "Lina", "Philipp", "Ying", "Alka", "Gaurav", "Sofi", "Olja", "Miranda", "Nicha"]

# Shuffle the players
random.shuffle(players)

# Divide the players into two teams
team_A = players[:len(players)//2]
team_B = players[len(players)//2:]

print("Team A:", team_A)
print("Team B:", team_B)

print(len(players))

