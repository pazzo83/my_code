using Requests
using JSON

type Player
  player_id::ASCIIString
  logs::Dict
  totals::Dict
  career::Dict

  Player(player_id) = new(player_id)
end

function get_mlb_player(player_id::ASCIIString)
  #stuff
  mlb_url = "http://mlb.com/lookup/json/named.player_info.bam?sport_code='mlb'&player_id='$player_id'"
  print(mlb_url)

  res = get(mlb_url)

  my_json = JSON.parse(IOBuffer(res.data))

  print(my_json)
end

player_id = "477132"

my_player = Player(player_id)

get_mlb_player(my_player.player_id)