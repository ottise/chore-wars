# Implementation Discipline

### No Fully Qualified Type Names in Source Code

Do not use fully qualified namespace names directly in source code when a `using` directive can be used.

❌ Bad:
```csharp
options.Filters.Add<ChoreWars.Presentation.Filters.ValidationFilter>();
```

✅ Good:
```csharp
using ChoreWars.Presentation.Filters;

options.Filters.Add<ValidationFilter>();
```

**Rules:**
- Always prefer using directives at the top of the file.
- Do not repeat full namespaces inside method bodies, generic type arguments, attributes, object creation, or type declarations.
- Before adding a new type reference, check whether its namespace is already imported.
- If the namespace is not imported, add the required using directive at the top of the file.
- Keep all using directives at the top of the file.
- Do not use namespace aliases unless there is an actual naming conflict.
- Do not use fully qualified names merely to make the type explicit.
- Apply this rule consistently across the entire codebase, including existing code and newly generated code.

Example:

❌ Bad:
```csharp
services.AddScoped<ChoreWars.Application.Interfaces.Services.IChoreService>();
services.AddScoped<ChoreWars.Infrastructure.Repositories.ChoreRepository>();
```

✅ Good:
```csharp
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Infrastructure.Repositories;

services.AddScoped<IChoreService>();
services.AddScoped<ChoreRepository>();
```

### Source Code Cleanup

When modifying a file, remove unnecessary fully qualified namespace references and replace them with appropriate `using` directives. Apply this consistently across the entire backend source code. Do not leave mixed styles where some types use `using` directives and others use fully qualified namespaces without a naming conflict.

=> **Core Rule:** "Không được viết ChoreWars.Xxx.Xxx trực tiếp trong source. Nếu không có conflict thì luôn import namespace bằng using ở đầu file."
