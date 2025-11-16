# ==============================================
# COUNTERPOINT ENGINE - Pure Note Selection
# ==============================================
# No instrument-specific code - just counterpoint logic
# Returns notes based on rules, context, and voice range

# Load base counterpoint rules
run_file "./counterpoint_rules.rb"

# ==============================================
# NOTE SELECTION FUNCTIONS
# ==============================================

define :choose_opening_note do |voice_type|
  # Start on a note appropriate for voice range
  case voice_type
  when :soprano
    [72, 74, 76].choose  # C5, D5, E5
  when :alto
    [65, 67, 69].choose  # F4, G4, A4
  when :tenor
    [60, 62, 64].choose  # C4, D4, E4
  when :bass
    [48, 50, 52, 55, 57, 60].choose  # C3-C4 range
  end
end

define :choose_response_opening do |their_note, voice_type|
  # Respond with perfect consonance (octave, fifth, or unison)
  candidates = []
  
  # Try different perfect consonances
  [-12, -7, 0, 7, 12].each do |interval|
    note = their_note + interval
    if in_range(note, voice_type) && !voices_crossed(their_note, note)
      candidates << note
    end
  end
  
  candidates.choose || their_note - 12  # Fallback: octave below
end

define :choose_cadence_note do |their_note, my_prev, position, phrase_length, voice_type|
  is_penultimate = (position == phrase_length - 2)
  is_final = (position >= phrase_length - 1)
  
  if voice_type == :bass
    # Bass: penultimate = V (dominant), final = I (tonic)
    if is_penultimate
      67  # G4 (dominant in C major)
    elsif is_final
      60  # C4 (tonic)
    end
  else
    # Upper voices: approach final by step
    final = their_note + 12  # Octave above bass
    if is_penultimate
      final - 1  # Leading tone
    elsif is_final
      final
    end
  end
end

define :choose_middle_phrase_note do |their_note, their_prev, my_prev, voice_type|
  # Try contrary motion first (preferred)
  note = contrary_motion_note(their_prev, their_note, my_prev, voice_type)
  
  # Fall back to first species rules if contrary motion not possible
  if note.nil?
    note = first_species_move(their_prev, their_note, my_prev, voice_type)
  end
  
  # Absolute fallback: any consonance
  if note.nil?
    candidates = valid_counterpoint_notes(their_note, voice_type)
    note = candidates.choose
  end
  
  note
end

define :choose_next_note do |their_note, their_prev, my_prev, position, phrase_length, voice_type|
  # No note from other voice yet
  if their_note.nil?
    return choose_opening_note(voice_type)
  end
  
  # First response (no previous note of our own)
  if my_prev.nil?
    return choose_response_opening(their_note, voice_type)
  end
  
  # Cadence (end of phrase)
  if position >= phrase_length - 2
    return choose_cadence_note(their_note, my_prev, position, phrase_length, voice_type)
  end
  
  # Middle of phrase
  choose_middle_phrase_note(their_note, their_prev, my_prev, voice_type)
end

# ==============================================
# ANALYSIS FUNCTIONS
# ==============================================

define :analyze_move do |their_prev, their_note, my_prev, my_note|
  return nil if their_prev.nil? || my_prev.nil?
  
  motion = motion_type(their_prev, their_note, my_prev, my_note)
  interval = (my_note - their_note).abs % 12
  
  consonance_type = if is_perfect_consonance(interval)
    "perfect"
  elsif is_imperfect_consonance(interval)
    "imperfect"
  else
    "dissonant"
  end
  
  violations = []
  
  if has_parallel_fifths_or_octaves(their_prev, their_note, my_prev, my_note)
    violations << "parallel_fifths_or_octaves"
  end
  
  if has_hidden_fifths_or_octaves(their_prev, their_note, my_prev, my_note)
    violations << "hidden_fifths_or_octaves"
  end
  
  if !is_consonant(interval)
    violations << "dissonance"
  end
  
  {
    motion: motion,
    interval: interval,
    consonance: consonance_type,
    violations: violations,
    stepwise: is_stepwise(my_prev, my_note)
  }
end

define :log_move do |note, analysis, position|
  note_name = note_info(note).midi_string
  
  if analysis.nil?
    puts "[#{position}] #{note} (#{note_name})"
    return
  end
  
  motion_str = analysis[:motion].to_s
  cons_str = analysis[:consonance]
  interval_str = analysis[:interval]
  step_str = analysis[:stepwise] ? "step" : "leap"
  
  violations_str = if analysis[:violations].length > 0
    " ⚠️  " + analysis[:violations].join(", ")
  else
    ""
  end
  
  puts "[#{position}] #{note} (#{note_name}) | #{motion_str} | #{cons_str} (#{interval_str}) | #{step_str}#{violations_str}"
end
