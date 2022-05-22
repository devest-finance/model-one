const DevestOne = artifacts.require("DevestOne");
const ERC20Token = artifacts.require("ERC20Token");

module.exports = function(deployer) {
  if (deployer.network === 'development') {
      deployer.deploy(ERC20Token, "0xECF5A576A949aEE5915Afb60E0e62D09825Cd61B", "ERC20 Token", "TKO", 5, 1000000000000)
        .then(() => ERC20Token.deployed())
        .then(_instance => deployer.deploy(DevestOne, _instance.address));
  } else {
    deployer.deploy(DevestOne);
  }
};
