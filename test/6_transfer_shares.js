const AccountHelper = require("./helpers/Helper");

const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const ModelOne = artifacts.require("ModelOne");
const ModelOneFactory = artifacts.require("ModelOneFactory");

var exampleModelAddress = null;


contract('Transfer Shares', (accounts) => {

    let erc20Token;
    let modelOneFactory;
    let modelOneDeVestDAO;
    let modelOneInstance;

    before(async () => {
        erc20Token = await ERC20.deployed();
        modelOneFactory = await ModelOneFactory.deployed();
        modelOneDeVestDAO = await ModelOne.at(await modelOneFactory.root.call());
        await AccountHelper.setupAccountFunds(accounts, erc20Token, 40000000000);
        modelOneInstance = await AccountHelper.createTangible(modelOneFactory, erc20Token.address,
            "Example", "EXP", 3000000000, 10, 0,  accounts[0]);
        exampleModelAddress = modelOneInstance.address;
    });

    it('Transfer shares to others', async () => {
        await modelOneInstance.transfer(accounts[1], 30, { from: accounts[0], value: 10000000 });
        await modelOneInstance.transfer(accounts[2], 10, { from: accounts[0], value: 10000000 });
        await modelOneInstance.transfer(accounts[0], 10, { from: accounts[1], value: 10000000 });

        assert.equal(await AccountHelper.getShares(modelOneInstance, accounts[0]), 70, "Invalid shares on owner");
        assert.equal(await AccountHelper.getShares(modelOneInstance, accounts[1]), 20, "Invalid shares on owner");
        assert.equal(await AccountHelper.getShares(modelOneInstance, accounts[2]), 10, "Invalid shares on owner");
    });

});
