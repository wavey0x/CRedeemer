import pytest
from brownie import Contract
from brownie import accounts, config, network, project, web3


@pytest.fixture
def scdai():
    token_address = "0x8D9AED9882b4953a0c9fa920168fa1FDfA0eBE75"  # scDAI
    yield Contract(token_address)

@pytest.fixture
def dai():
    token_address = "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E"  # DAI
    yield Contract(token_address)

@pytest.fixture
def RELATIVE_APPROX():
    yield 1e-5

@pytest.fixture
def gov(accounts):
    addr = "0xC0E2830724C946a6748dDFE09753613cd38f6767"
    yield accounts.at(addr, force=True)

@pytest.fixture
def redeemer(CRedeemer, accounts, gov):
    yield gov.deploy(CRedeemer)

@pytest.fixture
def whale(dai, accounts):
    address = "0x27E611FD27b276ACbd5Ffd632E5eAEBEC9761E40"
    assert dai.balanceOf(address) > 100e18
    yield accounts.at(address, force=True)