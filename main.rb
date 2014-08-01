require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?

set :sessions, true
#session holds: name, deck, player_hand, dealer_hand, player_amount, bet_amount

BLACKJACK = 21
DEALER_STAY_VALUE = 17
INITIAL_AMOUNT = 500

helpers do
  def total(cards)
    @values = cards.map{|e| e[1]}
    @total = 0
    @aces = 0

    @values.each do |v|
      if v =='ace'
        @total += 11
        @aces += 1
      else
        @total += (v.to_i==0 ? 10 : v.to_i)
      end
    end

    @aces.times do
      if @total > BLACKJACK
        @total -= 10
      end
    end   
    @total
  end

  def card_display(card) #[suit,'value']
    "<img src='/images/cards/#{card[0]}_#{card[1]}.jpg' class='card'/>"
  end
end

before do
  @show_hit_stay_hide_dealer_card = true
  #@winner = false (not required to set, will be false if not defined)
end

get '/' do
  if !session[:name] #no player name is set
    redirect '/set_name'
  else
    redirect '/bet'
  end
end

get '/set_name' do
  session[:name]=nil
  erb :set_name
end

post '/set_name' do
  session[:name]=params[:player_name]
  if session[:name].empty?
    @error ="You have not entered any name. Please enter your name in the box below."
    halt erb :set_name
  elsif session[:name][/[a-zA-Z,' ',-]+/]!= session[:name]
    @error ="You have entered a very strange name. Please enter your name using only letters."
    halt erb :set_name
  end
  session[:player_amount]=INITIAL_AMOUNT
  redirect '/bet'
end

get '/bet' do
  if session[:player_amount] == 0
    @no_money = true
  end
  if ( !session[:player_amount] || !session[:name])
    halt redirect '/set_name'
  end
  session[:bet_amount]=nil
  erb :bet
end

post '/bet' do
  session[:bet_amount]=params[:bet_amount].to_i
  if session[:player_amount] == 0
    session[:player_amount] = session[:bet_amount]
  end
  if (session[:bet_amount] <= 0) || (session[:bet_amount] > session[:player_amount])
    @error = "You must enter a value between 1 and the total amount you have."
    erb :bet
  else
  redirect '/game'
  end
end

get '/game' do

    #new game - setup game values
    SUITS = ['hearts', 'diamonds', 'clubs', 'spades']
    VALUES = ['ace', '2', '3', '4', '5', '6', '7', '8', '9', '10',
                 'jack', 'queen', 'king']
    session[:deck]=SUITS.product(VALUES).shuffle!

    session[:player_hand]=[]
    session[:dealer_hand]=[]
    2.times{
      session[:player_hand]<<session[:deck].pop
      session[:dealer_hand]<<session[:deck].pop}
    
    erb :game
end

post '/game/player/hit' do
  @player_total=total(session[:player_hand])
  
  if @player_total < BLACKJACK
    # deal new card
    session[:player_hand]<<session[:deck].pop
    @player_total=total(session[:player_hand])
  end
  
  if @player_total == BLACKJACK
    @game_msg="Congratulations #{session[:name]}, you have a total of 21 Blackjack!"
  elsif @player_total > BLACKJACK
    @game_msg="Sorry #{session[:name]}, your total of #{@player_total} is too high!" +
      " You are bust!"
  end
  if @game_msg
    @show_hit_stay_hide_dealer_card = false
  end
  erb :game, layout: false
end

post '/game/player/stay' do
  @show_hit_stay_hide_dealer_card = false
  @game_msg = "You have chosen to stay."
  erb :game, layout: false
end

get '/reset' do
  if ((session[:name]||="").empty? || (session[:name][/[a-zA-Z,' ',-]+/]!= session[:name]))
    @error ="You have not entered a valid name. Please enter your name in the box below."
    halt erb :set_name
  end
  redirect '/bet'
end

post '/game/dealer/hit' do
  @show_hit_stay_hide_dealer_card = false
  
  session[:dealer_hand]<<session[:deck].pop

  erb :game, layout: false
end

post '/game/winner' do
  @show_hit_stay_hide_dealer_card = false
  @winner=true

  @player_total=total(session[:player_hand])
  @dealer_total=total(session[:dealer_hand])

  if (@player_total > BLACKJACK && @dealer_total > BLACKJACK)
    @success = "Both #{session[:name]} and the dealer are bust. This game is a tie!"
  elsif @dealer_total > BLACKJACK
    @success = "Dealer is bust. #{session[:name]} wins with a total of #{@player_total}!"
    session[:player_amount]+=session[:bet_amount]
  elsif @player_total > BLACKJACK
    @success = "#{session[:name]} is bust. The dealer wins with a total of #{@dealer_total}!"
    session[:player_amount]-=session[:bet_amount]
  elsif @player_total == @dealer_total
    @success = "Both #{session[:name]} and the dealer have a total of #{@player_total}. This game is a tie!"
  elsif @player_total > @dealer_total
    @success = "#{session[:name]} wins with a total of #{@player_total}!"
    session[:player_amount]+=session[:bet_amount]
  else
    @success = "Sorry #{session[:name]}, you lose this game. The dealer has beaten you with a total of #{@dealer_total}."
    session[:player_amount]-=session[:bet_amount]
  end

  @success << " #{session[:name]} now has $#{session[:player_amount]}."
  erb :game
end