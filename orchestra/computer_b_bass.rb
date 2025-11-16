# Computer B - Bass Voice
# Networked musical dialogue - listens and responds
use_bpm 90
use_real_time

# Network config - UPDATE THESE FOR YOUR SETUP
set :their_ip, "192.168.1.100"  # Computer A's IP address
set :their_port, 4560
set :my_name, "Bass"

use_osc get[:their_ip], get[:their_port]

# Musical state
set :last_heard_note, nil
set :my_turn, false

puts "#{get[:my_name]} starting - bidirectional mode"
puts "Listening for notes on port 4560..."

# Listen for notes from Computer A
live_loop :listen do
  note_msg = sync "/osc*/note"
  their_note = note_msg[0]

  set :last_heard_note, their_note
  puts "Heard: #{their_note} (#{note_info(their_note).midi_string})"

  set :my_turn, true
end

# Play and respond
live_loop :play_and_respond do
  if get[:my_turn] == true
    use_synth :bass_foundation

    last_note = get[:last_heard_note]

    if last_note.nil?
      sleep 0.25
    else
      # Respond with bass note - fifth up from what we heard
      note = last_note + 7

      puts "Responding: #{note} (#{note_info(note).midi_string})"

      play note, amp: 1.0, release: 1.5
      osc "/note", note
    end

    set :my_turn, false
    sleep 1
  else
    sleep 0.25
  end
end
