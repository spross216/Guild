# Guild pack for the __Name__ standards. Only accepted standards (standards/) reach agents.
@{
    Name        = '__Name__'
    Version     = '0.1.0'
    Contract    = '1'
    Description = '__Description__'
    Prefix      = '__Prefix__'
    Knowledge   = @(
        @{ Name = 'decisions'; Kind = 'decisions'; Path = '../decisions' }
        @{ Name = 'standards'; Kind = 'standards'; Path = '../standards' }
    )
}
