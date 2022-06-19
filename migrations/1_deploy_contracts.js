const ERC20 = artifacts.require("ERC20");
const DevestOne = artifacts.require("DevestOne");
const DevestOneNative = artifacts.require("DevestOneNative");

module.exports = function(deployer) {
  if (deployer.network === 'development') {
      deployer.deploy(ERC20, "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B", "ERC20 Token", "TKO", 5, 1000000000000)
        .then(() => ERC20.deployed())
        .then(_instance => deployer.deploy(DevestOne, _instance.address, "Example", "EXP"))
        .then(_instance => deployer.deploy(DevestOneNative, _instance.address, "ExampleNative", "EXP"))
  } else {
    deployer.deploy(DevestOne);
  }
};
