const ModelOne = artifacts.require("ModelOne");
const ModelOneFactory = artifacts.require("ModelOneFactory");

const ERC20 = artifacts.require("ERC20PresetFixedSupply");

var devestDAOAddress = null;
var exampleModelAddress = null;

contract('Testing Deployments', (accounts) => {

    it('Verify root (DeVest) DAO was deployed', async () => {
        const modelOneFactory = await ModelOneFactory.deployed();
        const devestDAOAddress = await modelOneFactory.root.call();

        const devestDAO = await ModelOne.at(devestDAOAddress);
        const symbol = await devestDAO.symbol.call();

        assert.equal(symbol, "% DeVest DAO", "Failed to issue DeVest DAO Contract");
    });

    it('Deploy ModelOne as DAO (Token)', async () => {
        const modelOneFactory = await ModelOneFactory.deployed();
        const erc20Token = await ERC20.deployed();

        const exampleOneContract = await modelOneFactory.issue(erc20Token.address, "Example", "EXP", { value: 100000000 });
        exampleModelAddress = exampleOneContract.logs[0].args[1];

        const devestDAO = await ModelOne.at(exampleModelAddress);
        const symbol = await devestDAO.symbol.call();

        assert.equal(symbol, "% EXP", "Failed to issue Example Contract");
    });

    it('Check ModelOne', async () => {
        const devestOne = await ModelOne.at(exampleModelAddress);

        // check if variables set
        const name = await devestOne.name.call();
        assert(name, "Example", "Invalid name on TST");

        await devestOne.initialize(3000000000, 10, 0, { from: accounts[0] });

        const value = (await devestOne.value.call()).toNumber();
        assert.equal(value, 3000000000, "Invalid price on initialized tangible");
    });

});
