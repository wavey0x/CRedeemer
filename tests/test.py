import pytest
import brownie
from brownie import config, Contract, accounts, interface, chain
from brownie import network


def test_operation(gov, redeemer, dai, scdai, whale, RELATIVE_APPROX):
    fromGov = {"from": gov}
    fromWhale = {"from": whale}
    assert scdai.balanceOf(gov) > 0
    scdai.transfer(redeemer, scdai.balanceOf(gov), fromGov)

    repayment_amount = 100e18
    chain.snapshot()
    # Test for rounding errors
    for i in range(0,15):
        repayment_amount += 1
        repayment_amount += 1e8
        repayment_amount += 1_000e18
        beginning_bal = dai.balanceOf(scdai)
        dai.transfer(scdai, repayment_amount, fromWhale)

        before = dai.balanceOf(scdai)
        gov_before = dai.balanceOf(gov)
        tx = redeemer.redeemMax(scdai, fromWhale)
        after = dai.balanceOf(scdai)
        retrieved = tx.events["Retrieved"]["amount"]
        print("Amount redeemed:", retrieved)
        gov_gain = dai.balanceOf(gov) - gov_before
        
        assert before > after
        assert after ==0
        assert pytest.approx(retrieved, rel=RELATIVE_APPROX) == repayment_amount + beginning_bal
        assert retrieved == gov_gain
        chain.revert()
    
    repayment_amount = dai.balanceOf(whale)
    dai.transfer(scdai, repayment_amount, fromWhale)

    before = dai.balanceOf(scdai)
    
    gov_before = dai.balanceOf(gov)
    tx = redeemer.redeemMax(scdai, fromWhale)
    after = dai.balanceOf(scdai)
    retrieved = tx.events["Retrieved"]["amount"]
    print("Amount redeemed:", retrieved)
    gov_gain = dai.balanceOf(gov) - gov_before
    
    assert before > after
    assert after !=0
    assert retrieved == gov_gain

    chain.reset()

    
def test_retrieve(gov, redeemer, dai, scdai, whale, RELATIVE_APPROX):
    amount = 100e8
    assert scdai.balanceOf(gov) > amount
    scdai.transfer(redeemer, amount, {"from": gov})
    dai.transfer(redeemer, 100e18, {"from": whale})
    with brownie.reverts():
        redeemer.retrieveToken(dai, {"from": whale})
        redeemer.retrieveToken(scdai, {"from": whale})

    before = dai.balanceOf(gov)
    before_sdcai = scdai.balanceOf(gov)

    redeemer.retrieveTokenExact(dai, 50e18, {"from": gov})
    assert dai.balanceOf(gov) - before == 50e18
    redeemer.retrieveToken(dai, {"from": gov})
    assert dai.balanceOf(gov) - before > 50e18

    redeemer.retrieveToken(scdai, {"from": gov})
    assert scdai.balanceOf(gov) - before_sdcai > 0
    
def test_set_min_amount(gov, redeemer, dai, scdai, whale, RELATIVE_APPROX):
    scwftm = "0x5AA53f03197E08C4851CAD8C92c7922DA5857E5d"
    assert redeemer.minAmounts(scwftm) == 0
    redeemer.setMinAmount(scwftm, 1e18, {"from":gov})
    assert redeemer.minAmounts(scwftm) == 1e18