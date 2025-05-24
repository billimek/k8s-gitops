# GitHub Copilot Modular Instructions

This directory contains modular instruction files for different aspects of the k8s-gitops repository. These files serve as detailed reference documentation and a source of truth for the main `.github/copilot-instructions.md` file.

## Purpose of This Approach

The modular approach helps with:

1. **Organization**: Breaking down complex guidelines by component
2. **Maintenance**: Updating specific sections without editing the entire instructions file
3. **Collaboration**: Allowing different team members to own different aspects of guidelines
4. **Future-Proofing**: Preparing for potential future support of modular instructions

## Important Note About GitHub Copilot

As of May 2025, GitHub Copilot:

- **Only reads** the main `.github/copilot-instructions.md` file
- **Does not follow** links or references to other instruction files
- **Does not support** conditional application of instructions based on file types

The main file must contain all instructions needed by GitHub Copilot. References to these modular files in the main instructions file are for human readers only.

## File Descriptions

- `flux.instructions.md`: Detailed FluxCD configuration guidelines
- `helmrelease.instructions.md`: Complete HelmRelease patterns and examples
- `talos.instructions.md`: Talos OS configuration best practices
- `applications.instructions.md`: Application deployment patterns
- `secrets.instructions.md`: Comprehensive secret management
- `external-secrets.instructions.md`: External Secrets with 1Password
- `yaml-schemas.instructions.md`: YAML Schema Validation Guidelines

## Workflow for Updates

When updating these instruction files:

1. Make your changes to the appropriate modular instruction file
2. Review the impact on the main instructions file
3. Update the corresponding section in the main `.github/copilot-instructions.md` file
4. Commit both changes together

This ensures that GitHub Copilot always has access to the most up-to-date guidance while maintaining the benefits of modular organization.
