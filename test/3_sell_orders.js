const AccountHelper = require("./helpers/Helper");

const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const ModelOne = artifacts.require("ModelOne");
const ModelOneFactory = artifacts.require("ModelOneFactory");

var exampleModelAddress = null;

contract('Sell Orders', (accounts) => {

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

    it("Create sell order", async () => {
        await modelOneInstance.sell(40000000, 25, { from: accounts[0] });

        const orders = await modelOneInstance.getOrders.call();
        assert.equal(orders[0], accounts[0], "Invalid sell order created");
    })

    it("Accept sell order", async () => {
        // --- before
        const fundsOwnerBefore = (await erc20Token.balanceOf.call(accounts[0])).toNumber();

        // fetch orders
        const pricePerShare = 40000000;
        const amountOfShares = 2;
        const totalPrice = pricePerShare * amountOfShares;
        const escrow = totalPrice + ((totalPrice) * 0.1); // totalPrice + tax (10%)

        await erc20Token.approve(modelOneInstance.address, escrow, { from: accounts[3] });
        const orders = await modelOneInstance.getOrders.call();
        await modelOneInstance.accept(orders[0], 2, { from: accounts[3], value: 10000000 });

        // check if tax was paid
        tax = 8000000;

        // check if owner got funds back
        const fundsOwnerAfter = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(fundsOwnerAfter, fundsOwnerBefore + (40000000 * 2) + tax, "Seller (owner) received invalid amount for swap");

        // no more funds on tangible ( all spend )
        const fundsTangible = (await erc20Token.balanceOf.call(modelOneInstance.address)).toNumber();
        assert.equal(fundsTangible, 0, "Invalid funds on tangible after accept");

        const value = (await modelOneInstance.value.call()).toNumber();
        assert.equal((value/100), 30200000, "Invalid price, in PreSale phase");
        // 40000000

        const shareOwner = (await modelOneInstance.getShares.call(accounts[0])).toNumber();
        const share3 = (await modelOneInstance.getShares.call(accounts[3])).toNumber();
        assert.equal(shareOwner, 98, "Invalid share of staker");
        assert.equal(share3, 2, "Invalid share of staker");
    });

    it('Check if fees been collected in DeVest DAO', async () => {
        const balance = await web3.eth.getBalance(await modelOneFactory.root.call());
        assert.equal(balance, 110000000, "No Fees been paid to DAO");
    });

});
const createBid = async (percent, price, address) => {
    const erc20Token = await ERC20.deployed();
    const devestOne = await ModelOne.at(exampleModelAddress);

    // submit bid
    let escrow = price * percent;
    escrow = escrow + (escrow * 0.1)
    await erc20Token.approve(devestOne.address, escrow, { from: address });
    await devestOne.bid(price, percent, { from: address });
}
