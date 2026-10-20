using System.Diagnostics;
using ChoreWars.Infrastructure.Messaging.Kafka;

namespace IntegrationTests.Infrastructure;

public sealed class WorkerProcessHarness : IAsyncDisposable
{
    private readonly Process _process;
    private readonly string _ack;
    private readonly Task<string> _stdout;
    private readonly Task<string> _stderr;
    private WorkerProcessHarness(Process process,string ack) {
        _process=process;_ack=ack;_stdout=process.StandardOutput.ReadToEndAsync();_stderr=process.StandardError.ReadToEndAsync();
    }
    public static WorkerProcessHarness Start(PostgresFixture db,string mode,string point,KafkaOptions? kafka=null,Guid? occurrence=null,Guid? user=null) {
        var root=new DirectoryInfo(AppContext.BaseDirectory);
        while(root!=null && !File.Exists(Path.Combine(root.FullName,"backend","ChoreWars.slnx"))) root=root.Parent;
        if(root==null) throw new InvalidOperationException("Repository root not found.");
        var configuration=new DirectoryInfo(AppContext.BaseDirectory).Parent!.Name;
        var assembly=Path.Combine(root.FullName,"backend","tests","WorkerTestHost","bin",configuration,"net10.0","WorkerTestHost.dll");
        if(!File.Exists(assembly)) throw new FileNotFoundException("Build WorkerTestHost before executing crash tests.",assembly);
        var directory=Path.Combine(root.FullName,"artifacts","runtime","process-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(directory);
        var ack=Path.Combine(directory,"probe.ack");
        var start=new ProcessStartInfo("dotnet") { UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,RedirectStandardOutput=true,RedirectStandardError=true,WorkingDirectory=root.FullName };
        start.ArgumentList.Add(assembly);
        start.Environment["ConnectionStrings__DefaultConnection"]=db.ConnectionString;
        start.Environment["DOTNET_ENVIRONMENT"]="Testing";
        start.Environment["TEST_WORKER_MODE"]=mode;start.Environment["TEST_PROBE_POINT"]=point;start.Environment["TEST_PROBE_ACK"]=ack;
        start.Environment["TEST_OCCURRENCE"]=occurrence?.ToString();start.Environment["TEST_USER"]=user?.ToString();
        start.Environment["Kafka__BootstrapServers"]=kafka?.BootstrapServers??"127.0.0.1:1";
        start.Environment["Kafka__ConsumerGroupId"]=kafka?.ConsumerGroupId??"unused-mutation-test";
        start.Environment["Kafka__TopicPrefix"]=kafka?.TopicPrefix??"";
        start.Environment["Kafka__SessionTimeoutMs"]=(kafka?.SessionTimeoutMs??45000).ToString();
        return new(Process.Start(start)??throw new InvalidOperationException("Could not start worker test process."),ack);
    }
    public async Task WaitForProbeAsync() {
        var timeout=DateTime.UtcNow.AddSeconds(60);
        while(DateTime.UtcNow<timeout) {
            if(File.Exists(_ack)) return;
            if(_process.HasExited) throw new InvalidOperationException("Worker exited before probe. "+await _stderr+await _stdout);
            await Task.Delay(100);
        }
        throw new TimeoutException("Worker did not reach the requested fault boundary.");
    }
    public async Task KillAsync() {
        if(!_process.HasExited) _process.Kill(entireProcessTree:true);
        await _process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(15));
    }
    public async ValueTask DisposeAsync() {
        await KillAsync();
        await File.WriteAllTextAsync(Path.Combine(Path.GetDirectoryName(_ack)!,"worker.log"),await _stdout+Environment.NewLine+await _stderr);
        _process.Dispose();
    }
}
