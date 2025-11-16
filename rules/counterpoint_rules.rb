# ==============================================
# COUNTERPOINT RULES FOR SONIC PI
# ==============================================

# Rule 1: Consonance Check
# Perfect consonances: unison (0), fifth (7), octave (12)
# Imperfect consonances: third (3,4), sixth (8,9)
# Dissonances: second (1,2), seventh (10,11), tritone (6)
define :is_consonant do |interval|
  interval = interval.abs % 12
  [0, 3, 4, 7, 8, 9, 12].include?(interval)
end

define :is_perfect_consonance do |interval|
  interval = interval.abs % 12
  [0, 7, 12].include?(interval)
end

define :is_imperfect_consonance do |interval|
  interval = interval.abs % 12
  [3, 4, 8, 9].include?(interval)
end

# Rule 2: Motion Type Detection
# Returns :contrary, :parallel, :similar, or :oblique
define :motion_type do |voice1_prev, voice1_curr, voice2_prev, voice2_curr|
  motion1 = voice1_curr - voice1_prev
  motion2 = voice2_curr - voice2_prev

  if motion1 == 0 && motion2 == 0
    :oblique
  elsif motion1 == 0 || motion2 == 0
    :oblique
  elsif (motion1 > 0 && motion2 < 0) || (motion1 < 0 && motion2 > 0)
    :contrary
  elsif motion1 == motion2
    :parallel
  else
    :similar
  end
end

# Rule 3: Avoid Parallel Fifths and Octaves
# Returns true if the motion creates forbidden parallels
define :has_parallel_fifths_or_octaves do |voice1_prev, voice1_curr, voice2_prev, voice2_curr|
  prev_interval = (voice2_prev - voice1_prev).abs % 12
  curr_interval = (voice2_curr - voice1_curr).abs % 12

  motion = motion_type(voice1_prev, voice1_curr, voice2_prev, voice2_curr)

  # Parallel perfect consonances are forbidden
  if motion == :parallel
    (prev_interval == 7 && curr_interval == 7) ||  # parallel fifths
    (prev_interval == 0 && curr_interval == 0) ||  # parallel unisons
    (prev_interval == 12 && curr_interval == 12)   # parallel octaves
  else
    false
  end
end

# Rule 4: Avoid Hidden (Direct) Fifths and Octaves
# Similar motion into a perfect consonance is only allowed if top voice moves by step
define :has_hidden_fifths_or_octaves do |voice1_prev, voice1_curr, voice2_prev, voice2_curr|
  curr_interval = (voice2_curr - voice1_curr).abs % 12
  motion = motion_type(voice1_prev, voice1_curr, voice2_prev, voice2_curr)
  top_voice_step = (voice2_curr - voice2_prev).abs <= 2

  if motion == :similar && is_perfect_consonance(curr_interval)
    !top_voice_step  # Forbidden if top voice doesn't move by step
  else
    false
  end
end

# Rule 5: Stepwise Motion Preference
# Counterpoint should move mostly by step (1-2 semitones)
define :is_stepwise do |prev_note, curr_note|
  interval = (curr_note - prev_note).abs
  interval <= 2
end

define :is_leap do |prev_note, curr_note|
  interval = (curr_note - prev_note).abs
  interval > 2
end

# Rule 6: Leap Recovery
# After a leap, should move by step in opposite direction
define :leap_recovery_note do |prev_note, curr_note|
  interval = curr_note - prev_note

  if interval.abs > 2  # It was a leap
    if interval > 0
      curr_note - [1, 2].choose  # Step down after upward leap
    else
      curr_note + [1, 2].choose  # Step up after downward leap
    end
  else
    nil  # No recovery needed
  end
end

# Rule 7: Voice Range Check
# Each voice should stay within comfortable range
define :in_range do |note, voice_type|
  case voice_type
  when :soprano
    note >= 60 && note <= 81  # C4 to A5
  when :alto
    note >= 53 && note <= 74  # F3 to D5
  when :tenor
    note >= 48 && note <= 69  # C3 to A4
  when :bass
    note >= 40 && note <= 60  # E2 to C4
  else
    true
  end
end

# Rule 8: Voice Crossing Check
# Voices should not cross (upper voice goes below lower)
define :voices_crossed do |lower_note, upper_note|
  upper_note < lower_note
end

# Rule 9: Voice Spacing
# Adjacent voices shouldn't be more than an octave apart (except bass)
define :proper_spacing do |lower_note, upper_note, allow_wide = false|
  interval = upper_note - lower_note
  if allow_wide
    interval <= 24  # Two octaves max for bass
  else
    interval <= 12  # One octave max
  end
end

# Rule 10: Generate Valid Counterpoint Note
# Given a cantus firmus note, find a valid counterpoint note
define :valid_counterpoint_notes do |cantus_note, voice_type = :soprano|
  valid_notes = []

  # Check all notes in the voice range
  range_start = case voice_type
    when :soprano then 60
    when :alto then 53
    when :tenor then 48
    when :bass then 40
  end

  range_end = case voice_type
    when :soprano then 81
    when :alto then 74
    when :tenor then 69
    when :bass then 60
  end

  (range_start..range_end).each do |note|
    interval = (note - cantus_note).abs % 12
    if is_consonant(interval) && !voices_crossed(cantus_note, note)
      valid_notes << note
    end
  end

  valid_notes
end

# Rule 11: First Species Counterpoint Move
# Choose next note avoiding all parallel/hidden issues
define :first_species_move do |cantus_prev, cantus_curr, counter_prev, voice_type = :soprano|
  candidates = valid_counterpoint_notes(cantus_curr, voice_type)

  # Filter out forbidden moves
  good_notes = candidates.select do |candidate|
    !has_parallel_fifths_or_octaves(cantus_prev, cantus_curr, counter_prev, candidate) &&
    !has_hidden_fifths_or_octaves(cantus_prev, cantus_curr, counter_prev, candidate) &&
    proper_spacing(cantus_curr, candidate)
  end

  # Prefer stepwise motion
  stepwise_notes = good_notes.select { |n| is_stepwise(counter_prev, n) }

  if stepwise_notes.length > 0
    stepwise_notes.choose
  elsif good_notes.length > 0
    good_notes.choose
  elsif candidates.length > 0
    # Fallback: any consonance
    candidates.choose
  else
    # Ultimate fallback: stay on current note
    counter_prev
  end
end

# Rule 12: Contrary Motion Preference
# When possible, move in contrary motion to cantus
define :contrary_motion_note do |cantus_prev, cantus_curr, counter_prev, voice_type = :soprano|
  cantus_direction = cantus_curr - cantus_prev
  candidates = valid_counterpoint_notes(cantus_curr, voice_type)

  contrary_notes = candidates.select do |candidate|
    counter_direction = candidate - counter_prev
    # Opposite direction
    (cantus_direction > 0 && counter_direction < 0) ||
    (cantus_direction < 0 && counter_direction > 0)
  end

  if contrary_notes.length > 0
    # Prefer stepwise contrary motion
    stepwise = contrary_notes.select { |n| is_stepwise(counter_prev, n) }
    stepwise.length > 0 ? stepwise.choose : contrary_notes.choose
  else
    nil
  end
end

# Rule 13: Cadence Approach
# Approach final note with specific patterns
define :cadence_approach do |final_note, voice_type, penultimate = true|
  if penultimate
    case voice_type
    when :soprano
      # Leading tone resolution (up by half step)
      final_note - 1
    when :bass
      # Authentic cadence: V-I (down by fifth or up by fourth)
      final_note + 7
    else
      # Step into final
      final_note + [1, 2, -1, -2].choose
    end
  else
    final_note
  end
end

# Rule 14: Dissonance Treatment (for Second Species+)
# Dissonances only allowed as passing tones on weak beats
define :valid_passing_tone do |prev_note, next_note, passing_note|
  # Must be stepwise approach and departure
  step_in = is_stepwise(prev_note, passing_note)
  step_out = is_stepwise(passing_note, next_note)
  # Must continue in same direction
  same_direction = ((passing_note - prev_note) > 0) == ((next_note - passing_note) > 0)

  step_in && step_out && same_direction
end

# Rule 15: Suspension Resolution
# Suspensions must resolve downward by step
define :suspension_resolution do |suspended_note|
  suspended_note - [1, 2].choose
end
