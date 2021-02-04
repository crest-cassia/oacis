require 'spec_helper'

describe JobNotificationUtil do
  let!(:sim) { FactoryBot.create(:simulator) }
  let!(:other_sim) { FactoryBot.create(:simulator) }

  let!(:ps) { FactoryBot.create(:parameter_set, simulator: sim) }
  let!(:other_ps) { FactoryBot.create(:parameter_set, simulator: sim) }
  let!(:other_sim_ps) { FactoryBot.create(:parameter_set, simulator: other_sim) }

  let!(:analyzer) { FactoryBot.create(:analyzer, simulator: sim) }
  let!(:other_sim_analyzer) { FactoryBot.create(:analyzer, simulator: other_sim) }

  before do
    Run.destroy_all
    Analysis.destroy_all
  end

  let!(:runs) { FactoryBot.create_list(:run, 2, status: :running, parameter_set: ps) }
  let!(:other_ps_run) { FactoryBot.create(:run, status: :running, parameter_set: other_ps) }
  let!(:other_sim_run) { FactoryBot.create(:run, status: :running, parameter_set: other_sim_ps) }

  let!(:analyses) { FactoryBot.create_list(:analysis, 2, status: :running, parameter_set: ps, analyzer: analyzer, analyzable: ps) }
  let!(:other_ps_analysis) { FactoryBot.create(:analysis, status: :running, parameter_set: other_ps, analyzer: analyzer, analyzable: other_ps) }
  let!(:other_sim_analysis) { FactoryBot.create(:analysis, status: :running, parameter_set: other_sim_ps, analyzer: other_sim_analyzer, analyzable: other_sim_run) }

  describe '#notify_job_finished' do
    context 'when notification_level is 1' do
      before { FactoryBot.create(:oacis_setting, notification_level: 1) }

      it do
        runs.each {|run| run.update!(status: :finished) }
        described_class.notify_job_finished(runs.second)
        expect(NotificationEvent.count).to eq 0

        other_ps_run.update!(status: :finished)
        described_class.notify_job_finished(other_ps_run)
        expect(NotificationEvent.count).to eq 1
        expect(NotificationEvent.last.message).to include('Run', 'SimulatorID')

        analyses.each {|run| run.update!(status: :finished) }
        described_class.notify_job_finished(analyses.second)
        expect(NotificationEvent.count).to eq 1

        other_ps_analysis.update!(status: :finished)
        described_class.notify_job_finished(other_ps_analysis)
        expect(NotificationEvent.count).to eq 2
        expect(NotificationEvent.last.message).to include('Analysis', 'SimulatorID')
      end
    end

    context 'when notification_level is 2' do
      before { FactoryBot.create(:oacis_setting, notification_level: 2) }

      it do
        runs.each {|run| run.update!(status: :finished) }
        described_class.notify_job_finished(runs.second)
        expect(NotificationEvent.count).to eq 1
        expect(NotificationEvent.last.message).to include('Run', 'ParameterSetID')

        other_ps_run.update!(status: :finished)
        described_class.notify_job_finished(other_ps_run)
        expect(NotificationEvent.count).to eq 3
        expect(NotificationEvent.last.message).to include('Run', 'SimulatorID')

        analyses.each {|run| run.update!(status: :finished) }
        described_class.notify_job_finished(analyses.second)
        expect(NotificationEvent.count).to eq 4
        expect(NotificationEvent.last.message).to include('Analysis', 'ParameterSetID')

        other_ps_analysis.update!(status: :finished)
        described_class.notify_job_finished(other_ps_analysis)
        expect(NotificationEvent.count).to eq 6
        expect(NotificationEvent.last.message).to include('Analysis', 'SimulatorID')
      end
    end

    context 'when notification_level is 3' do
      before { FactoryBot.create(:oacis_setting, notification_level: 3) }

      it do
        runs.first.update!(status: :finished)
        described_class.notify_job_finished(runs.first)
        expect(NotificationEvent.count).to eq 1
        expect(NotificationEvent.last.message).to include('RunID')

        runs.second.update!(status: :finished)
        described_class.notify_job_finished(runs.second)
        expect(NotificationEvent.count).to eq 3
        expect(NotificationEvent.last.message).to include('Run', 'ParameterSetID')

        other_ps_run.update!(status: :finished)
        described_class.notify_job_finished(other_ps_run)
        expect(NotificationEvent.count).to eq 6
        expect(NotificationEvent.last.message).to include('Run', 'SimulatorID')

        analyses.first.update!(status: :finished)
        described_class.notify_job_finished(analyses.first)
        expect(NotificationEvent.count).to eq 7
        expect(NotificationEvent.last.message).to include('AnalysisID')

        analyses.second.update!(status: :finished)
        described_class.notify_job_finished(analyses.second)
        expect(NotificationEvent.count).to eq 9
        expect(NotificationEvent.last.message).to include('Analysis', 'ParameterSetID')

        other_ps_analysis.update!(status: :finished)
        described_class.notify_job_finished(other_ps_analysis)
        expect(NotificationEvent.count).to eq 12
        expect(NotificationEvent.last.message).to include('Analysis', 'SimulatorID')
      end
    end
  end
end
