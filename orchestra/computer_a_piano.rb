##| # Computer A - Piano Leader - WORKING
##| use_bpm 90
##| use_real_time

##| # Network config
##| set :their_ip, "192.168.50.58"
##| set :their_port, 4560

##| use_osc get[:their_ip], get[:their_port]

##| puts "Computer A (Piano) starting..."
##| puts "Sending notes to #{get[:their_ip]}:#{get[:their_port]}"

##| live_loop :piano_leader do
##|   use_synth :piano

##|   # Play a random note from C major scale
##|   note = (scale :c4, :major).choose

##|   play note, amp: 0.8, release: 1

##|   # Broadcast what we played
##|   osc "/note", note
##|   puts "Played: #{note} (#{note_info(note).midi_string})"

##|   sleep 1
##| end

# Computer A - Piano (Conversational) - WORKING
##| use_bpm 132
##| use_real_time

##| # Network config
##| set :their_ip, "192.168.50.58"
##| set :their_port, 4560
##| set :my_name, "Piano"

##| use_osc get[:their_ip], get[:their_port]

##| # Musical state
##| set :last_heard_note, nil
##| set :my_turn, true  # Start with initiative

##| puts "#{get[:my_name]} starting - bidirectional mode"

##| # Listen for their notes
##| live_loop :listen do
##|   note_msg = sync "/osc*/note"
##|   their_note = note_msg[0]
##|   sender = note_msg[1]

##|   set :last_heard_note, their_note
##|   puts "Heard #{sender}: #{their_note} (#{note_info(their_note).midi_string})"

##|   # Their turn is over, now it's mine
##|   set :my_turn, true
##| end

##| # Play and respond
##| live_loop :play_and_respond do
##|   if get[:my_turn] == true
##|     use_synth :piano

##|     last_note = get[:last_heard_note]

##|     # Decide what to play
##|     if last_note.nil?
##|       # No one has played yet, start the conversation
##|       note = (scale :c4, :major).choose
##|       puts "Initiating: #{note}"
##|     else
##|       # Respond to what we heard
##|       # Sometimes harmonize (fifth), sometimes answer (octave), sometimes new idea
##|       response_type = [:fifth, :octave, :new].choose

##|       note = case response_type
##|       when :fifth
##|         last_note + 7  # Harmonize
##|       when :octave
##|         last_note + 12  # Echo higher
##|       when :new
##|         (scale :c4, :major).choose  # New idea
##|       end

##|       puts "Responding with #{response_type}: #{note}"
##|     end

##|     play note, amp: 0.8, release: 1

##|     # Broadcast with our name so they know who played
##|     osc "/note", note, get[:my_name]

##|     # Give them a turn
##|     set :my_turn, false

##|     sleep 1  # Wait before we could play again
##|   else
##|     # Not our turn, just wait
##|     sleep 0.25
##|   end
##| end

live_loop :funky_rhythm do
  use_synth :tb303
  
  # Alternating note pattern
  play (ring :e2, :e3, :e2, :a2).tick(:notes), release: 0.2, cutoff: 80
  
  # Funky rhythm: short-long-short-medium
  sleep (ring 0.125, 0.25, 0.125, 0.5).tick(:timing)
end
