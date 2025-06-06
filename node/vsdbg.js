// Define the path to the native module
const vsda_location = 'C:\\Users\\Alex.Mainstone\\AppData\\Local\\Programs\\Microsoft VS Code\\resources\\app\\node_modules.asar.unpacked\\vsda\\build\\Release\\vsda.node';

// Load the native module
const a = require(vsda_location);

// Create an instance of the signer class
const signer = new a.signer();

// Loop through command-line arguments (starting from index 2)
process.argv.slice(2).forEach((value) => {
  const result = signer.sign(value);
  console.log(result);
});

