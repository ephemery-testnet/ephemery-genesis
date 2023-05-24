var fs = require('fs');

async function main() {
  var types = await import("@lodestar/types");
  var BeaconState = types.ssz.capella.BeaconState;

  // read genesis.ssz
  var binary = fs.readFileSync(process.argv[process.argv.length - 1]);
  var beaconState = BeaconState.deserialize(binary)

  console.log("genesisTime: " + beaconState.genesisTime);
  console.log("genesisValidatorsRoot: 0x" + beaconState.genesisValidatorsRoot.toString('hex'));
}

main();
