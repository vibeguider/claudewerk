# Computer B - Bass with Counterpoint Rules
# Networked musical dialogue using classical counterpoint principles
use_bpm 90
use_real_time

# Load counterpoint rules
run_file "/Users/sma/claudewerk/rules/counterpoint_rules.rb"

# Network config - UPDATE THESE FOR YOUR SETUP
set :their_ip, "192.168.1.100"  # Computer A's IP address
set :their_port, 4560
set :my_name, "Bass"
set :my_voice_type, :bass

use_osc get[:their_ip], get[:their_port]

# Musical history for counterpoint tracking
set :my_prev_note, nil
set :my_curr_note, nil
set :their_prev_note, nil
set :their_curr_note, nil
set :my_turn, false

# LLM control parameters
set :style, "strict"  # strict, free, cadential

puts "#{get[:my_name]} (#{get[:my_voice_type]}) starting with counterpoint rules"
puts "Listening for notes on port 4560..."

# Listen for soprano/piano notes from Computer A
live_loop :listen do
  note_msg = sync "/osc*/note"
  their_note = note_msg[0]

  set :their_prev_note, get[:their_curr_note]
  set :their_curr_note, their_note

  puts "Heard Piano: #{their_note} (#{note_info(their_note).midi_string})"
  set :my_turn, true
end

# Play bass line with counterpoint rules
live_loop :counterpoint_bass do
  if get[:my_turn] == true
    use_synth :bass_foundation

    soprano_note = get[:their_curr_note]
    my_prev = get[:my_curr_note]
    soprano_prev = get[:their_prev_note]

    if soprano_note.nil?
      sleep 0.25
    elsif my_prev.nil? || soprano_prev.nil?
      # First note - pick consonant note below soprano
      candidates = valid_counterpoint_notes(soprano_note, get[:my_voice_type])
      # Bass should be BELOW soprano
      bass_candidates = candidates.select { |n| n < soprano_note - 12 }
      note = bass_candidates.choose || (soprano_note - 24)  # Two octaves below fallback
      puts "First bass note: #{note} (#{note_info(note).midi_string})"
    else
      # Full counterpoint logic!

      # Get candidates that won't cause parallel fifths/octaves
      candidates = valid_counterpoint_notes(soprano_note, get[:my_voice_type])

      good_notes = candidates.select do |candidate|
        candidate < soprano_note &&  # Stay below soprano
        !has_parallel_fifths_or_octaves(my_prev, candidate, soprano_prev, soprano_note) &&
        !has_hidden_fifths_or_octaves(my_prev, candidate, soprano_prev, soprano_note) &&
        proper_spacing(candidate, soprano_note, true)  # Allow wide spacing for bass
      end

      # Prefer contrary motion to soprano
      soprano_direction = soprano_note - soprano_prev
      contrary_notes = good_notes.select do |n|
        bass_direction = n - my_prev
        (soprano_direction > 0 && bass_direction < 0) ||
        (soprano_direction < 0 && bass_direction > 0)
      end

      # Choose based on style
      case get[:style]
      when "strict"
        # Prefer stepwise contrary motion
        if contrary_notes.length > 0
          stepwise = contrary_notes.select { |n| is_stepwise(my_prev, n) }
          note = stepwise.length > 0 ? stepwise.choose : contrary_notes.choose
          puts "Contrary bass: #{note} | Motion: #{motion_type(my_prev, note, soprano_prev, soprano_note)}"
        elsif good_notes.length > 0
          stepwise = good_notes.select { |n| is_stepwise(my_prev, n) }
          note = stepwise.length > 0 ? stepwise.choose : good_notes.choose
          puts "Valid bass: #{note}"
        else
          # Fallback - hold current note
          note = my_prev
          puts "Holding note: #{note}"
        end

      when "free"
        # More relaxed - just avoid parallel fifths
        if good_notes.length > 0
          note = good_notes.choose
          puts "Free bass: #{note}"
        else
          note = candidates.select { |n| n < soprano_note }.choose || my_prev
          puts "Fallback bass: #{note}"
        end

      when "cadential"
        # Approaching cadence - authentic cadence motion
        # Move toward dominant then tonic
        note = cadence_approach(48, get[:my_voice_type])  # Approach C3
        puts "Cadential bass: #{note}"
      end

      # Report the interval for debugging
      interval = (soprano_note - note).abs % 12
      consonance = is_consonant(interval) ? "consonant" : "DISSONANT"
      puts "  Interval: #{interval} semitones (#{consonance})"

      # Check motion type
      if my_prev && soprano_prev
        motion = motion_type(my_prev, note, soprano_prev, soprano_note)
        puts "  Motion: #{motion}"
      end
    end

    play note, amp: 1.0, release: 1.5

    # Update history
    set :my_prev_note, my_prev
    set :my_curr_note, note

    # Broadcast our note to Computer A
    osc "/note", note

    set :my_turn, false
    sleep 1
  else
    sleep 0.25
  end
end
