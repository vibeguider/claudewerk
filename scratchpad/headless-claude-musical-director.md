# Headless Claude Code as Musical Director

Using Claude Code in headless mode to drive musical decision-making for networked Sonic Pi instances.

## Basic Setup

```bash
# Run Claude Code headlessly with a prompt
claude -p "Change the bass response style to walking bass" --allowedTools "Edit,Read,Bash"
```

## Architecture Options

### Option 1: File-Based Control
Claude Code edits a config file that Sonic Pi watches:

```ruby
# In computer_b_bass.rb - add this at top
live_loop :reload_config do
  config = JSON.parse(File.read("/tmp/bass_config.json"))
  set :response_interval, config["interval"] || 7
  set :style, config["style"] || "simple"
  sleep 2
end

# In response section
note = last_note + get[:response_interval]
```

Then Claude Code can:
```bash
claude -p "Make the bass play minor thirds instead of fifths" --allowedTools "Edit"
# Claude edits /tmp/bass_config.json to set interval to 3
```

### Option 2: OSC Commands via Bash
Claude Code sends OSC messages directly:

```bash
# Install oscsend if needed
brew install liblo

# Claude can run:
claude -p "Tell the bass to increase energy" --allowedTools "Bash"
# Claude runs: oscsend localhost 4559 /style s "energetic"
```

Add to Sonic Pi:
```ruby
live_loop :control_listener do
  msg = sync "/osc*/style"
  set :style, msg[0]
  puts "Style changed to: #{msg[0]}"
end
```

### Option 3: Direct Code Injection
Claude Code writes new Sonic Pi code that gets hot-reloaded:

```bash
claude -p "Write a more complex bass response pattern that uses the counterpoint rules" \
  --allowedTools "Edit,Read"
```

## Practical Example

Create a control script:

```bash
#!/bin/bash
# musical_director.sh

while true; do
  # Claude analyzes the musical state and makes decisions
  claude -p "Read /tmp/music_state.json. Based on the current musical context,
             decide what the bass should do next. Update /tmp/bass_config.json
             with your decision. Be creative but musically sensible." \
    --allowedTools "Read,Edit" \
    --max-turns 1

  sleep 5  # Make decisions every 5 seconds
done
```

## Next Steps

- Create complete working example with config file approach
- Add state logging from Sonic Pi for Claude to analyze
- Implement bi-directional: Claude on both computers having meta-conversation about music
- Add counterpoint rule awareness to Claude's decision making
