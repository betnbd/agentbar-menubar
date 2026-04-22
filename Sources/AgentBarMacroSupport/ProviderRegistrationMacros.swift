@attached(peer, names: prefixed(_AgentBarDescriptorRegistration_))
public macro ProviderDescriptorRegistration() = #externalMacro(
    module: "AgentBarMacros",
    type: "ProviderDescriptorRegistrationMacro")

@attached(member, names: named(descriptor))
public macro ProviderDescriptorDefinition() = #externalMacro(
    module: "AgentBarMacros",
    type: "ProviderDescriptorDefinitionMacro")

@attached(peer, names: prefixed(_AgentBarImplementationRegistration_))
public macro ProviderImplementationRegistration() = #externalMacro(
    module: "AgentBarMacros",
    type: "ProviderImplementationRegistrationMacro")
