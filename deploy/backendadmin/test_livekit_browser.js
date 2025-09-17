// LiveKit Client Browser Test
// Copy and paste this into the browser console on https://admin.livekit.lovedrop.live/streaming_test

console.log('=== LiveKit Client Browser Test ===');

// Test 1: Check if LivekitClient is defined
if (typeof LivekitClient !== 'undefined') {
  console.log('✅ LivekitClient is defined');
  console.log('   Available properties:', Object.keys(LivekitClient).slice(0, 10).join(', ') + '...');
} else {
  console.error('❌ LivekitClient is NOT defined');
}

// Test 2: Check for Room constructor
if (typeof LivekitClient !== 'undefined' && typeof LivekitClient.Room === 'function') {
  console.log('✅ LivekitClient.Room constructor exists');
} else {
  console.error('❌ LivekitClient.Room constructor NOT found');
}

// Test 3: Check for RoomEvent enum
if (typeof LivekitClient !== 'undefined' && LivekitClient.RoomEvent) {
  console.log('✅ LivekitClient.RoomEvent exists');
  const events = Object.keys(LivekitClient.RoomEvent).slice(0, 5);
  console.log('   Sample events:', events.join(', ') + '...');
} else {
  console.error('❌ LivekitClient.RoomEvent NOT found');
}

// Test 4: Check for VideoPresets
if (typeof LivekitClient !== 'undefined' && LivekitClient.VideoPresets) {
  console.log('✅ LivekitClient.VideoPresets exists');
  const presets = Object.keys(LivekitClient.VideoPresets).slice(0, 5);
  console.log('   Sample presets:', presets.join(', ') + '...');
} else {
  console.error('❌ LivekitClient.VideoPresets NOT found');
}

// Test 5: Try to create a Room instance
try {
  const testRoom = new LivekitClient.Room({
    adaptiveStream: true,
    dynacast: true
  });
  console.log('✅ Successfully created Room instance');
  console.log('   Room state:', testRoom.state);
} catch (error) {
  console.error('❌ Failed to create Room instance:', error.message);
}

// Test 6: Check for other important classes
const classesToCheck = ['LocalTrack', 'RemoteTrack', 'LocalParticipant', 'RemoteParticipant', 'Track'];
classesToCheck.forEach(className => {
  if (typeof LivekitClient !== 'undefined' && typeof LivekitClient[className] === 'function') {
    console.log(`✅ LivekitClient.${className} exists`);
  } else {
    console.error(`❌ LivekitClient.${className} NOT found`);
  }
});

console.log('\n=== Test Complete ===');
console.log('If all tests pass, the LiveKit client is properly loaded and ready to use.');