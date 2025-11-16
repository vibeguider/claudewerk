# ==============================================
# COMPUTER B - BASS VOICE
# ==============================================

use_bpm 60
use_real_time

# Load dependencies
# Set CLAUDEWERK env var to your repo path, or it defaults to ~/claudewerk
repo = ENV['CLAUDEWERK'] || File.expand_path("~/claudewerk")
run_file "#{repo}/conductor/tuning.rb"
run_file "#{repo}/rules/counterpoint_engine.rb"

# Network setup
use_osc COMPUTER_A_IP, OSC_PORT

# Voice configuration
set :my_voice, :bass
set :my_name, "Bass"
set :my_synth, :bass_foundation
set :my_amp, 1.0
set :my_release, 2.0

# Musical state
set :last_heard_note, nil
set :my_previous_note, nil
set :their_previous_note, nil
set :my_turn, false  # Wait for soprano to start
set :phrase_position, 0
set :phrase_length, 8

puts "#{get[:my_name]} initialized → #{COMPUTER_A_IP}:#{OSC_PORT}"

# ==============================================
# NETWORK - Listen for their notes
# ==============================================

live_loop :listen do
  note_msg = sync "/osc*/note"
  their_note = note_msg[0]
  sender = note_msg[1]
  
  set :their_previous_note, get[:last_heard_note]
  set :last_heard_note, their_note
  
  puts "Heard #{sender}: #{their_note} (#{note_info(their_note).midi_string})"
  set :my_turn, true
end

# ==============================================
# PERFORMANCE - Play counterpoint
# ==============================================

live_loop :play do
  if get[:my_turn] == true
    # Choose next note using counterpoint engine
    note = choose_next_note(
      get[:last_heard_note],
      get[:their_previous_note],
      get[:my_previous_note],
      get[:phrase_position],
      get[:phrase_length],
      get[:my_voice]
    )

    # Analyze the move
    analysis = analyze_move(
      get[:their_previous_note],
      get[:last_heard_note],
      get[:my_previous_note],
      note
    )

    # Log
    log_move(note, analysis, get[:phrase_position])

    # Play with our instrument settings
    use_synth get[:my_synth]
    play note, amp: get[:my_amp], release: get[:my_release]

    # Update state
    set :my_previous_note, note
    set :phrase_position, get[:phrase_position] + 1

    # Broadcast
    osc "/note", note, get[:my_name]

    # Check if phrase complete
    if get[:phrase_position] >= get[:phrase_length]
      puts "--- Phrase complete ---"
      set :phrase_position, 0
      set :my_previous_note, nil
      set :their_previous_note, nil
      sleep 2
    end

    set :my_turn, false
    set :wait_count, 0
    sleep 1
  else
    # If we've waited too long, take another turn (keep playing even without response)
    wait_count = get[:wait_count] || 0
    if wait_count >= 8  # After 2 seconds of waiting
      set :my_turn, true
      set :wait_count, 0
    else
      set :wait_count, wait_count + 1
    end
    sleep 0.25
  end
end
