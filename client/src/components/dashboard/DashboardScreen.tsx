import { useCallback, useEffect, useState } from 'react'
import Box from '@mui/material/Box'
import Stack from '@mui/material/Stack'
import Typography from '@mui/material/Typography'
import { downloadBuild, listBuilds, streamBuild } from '../../api/buildApi'
import { getErrorMessage } from '../../api/http'
import type { AuthSession, BuildRecord, BuildStreamEvent, DashboardNotice } from '../../types'
import { saveBlobAsFile } from '../../utils/download'
import BuildLogPanel from './BuildLogPanel'
import BuildRecordsSection from './BuildRecordsSection'
import BuildSummaryCards from './BuildSummaryCards'
import DashboardHeader from './DashboardHeader'
import DashboardSnackbar from './DashboardSnackbar'
import DownloadBuildSelect from './DownloadBuildSelect'
import GenerateBuildForm from './GenerateBuildForm'

interface DashboardScreenProps {
  session: AuthSession
  onLogout: () => void
}

export default function DashboardScreen({ session, onLogout }: DashboardScreenProps) {
  const [records, setRecords] = useState<BuildRecord[]>([])
  const [isLoadingRecords, setIsLoadingRecords] = useState(true)
  const [recordsError, setRecordsError] = useState<string | null>(null)
  const [streamEvents, setStreamEvents] = useState<BuildStreamEvent[]>([])
  const [activeUuid, setActiveUuid] = useState<string | null>(null)
  const [downloadingUuid, setDownloadingUuid] = useState<string | null>(null)
  const [notice, setNotice] = useState<DashboardNotice | null>(null)

  const loadRecords = useCallback(async () => {
    setIsLoadingRecords(true)
    setRecordsError(null)

    try {
      setRecords(await listBuilds(session.token))
    } catch (requestError) {
      setRecordsError(getErrorMessage(requestError))
    } finally {
      setIsLoadingRecords(false)
    }
  }, [session.token])

  useEffect(() => {
    void Promise.resolve().then(loadRecords)
  }, [loadRecords])

  const handleStreamEvent = useCallback((event: BuildStreamEvent) => {
    setStreamEvents((currentEvents) => [...currentEvents, event])

    if (event.type === 'complete') {
      setNotice({ severity: 'success', message: event.message })
    }

    if (event.type === 'error') {
      setNotice({ severity: 'error', message: event.message })
    }
  }, [])

  const handleGenerateBuild = useCallback(
    async (uuid: string) => {
      setActiveUuid(uuid)
      setStreamEvents([])
      setNotice({ severity: 'info', message: `Build started for ${uuid}.` })

      try {
        await streamBuild(uuid, session.token, { onEvent: handleStreamEvent })
        await loadRecords()
      } catch (requestError) {
        const message = getErrorMessage(requestError)
        setStreamEvents((currentEvents) => [...currentEvents, { type: 'error', message }])
        setNotice({ severity: 'error', message })
        await loadRecords()
      } finally {
        setActiveUuid(null)
      }
    },
    [handleStreamEvent, loadRecords, session.token],
  )

  const handleDownloadBuild = useCallback(
    async (record: BuildRecord) => {
      setDownloadingUuid(record.uuid)

      try {
        const artifact = await downloadBuild(record.uuid, session.token)
        saveBlobAsFile(artifact.blob, artifact.filename)
        setNotice({ severity: 'success', message: `${artifact.filename} download started.` })
      } catch (requestError) {
        setNotice({ severity: 'error', message: getErrorMessage(requestError) })
      } finally {
        setDownloadingUuid(null)
      }
    },
    [session.token],
  )

  const handleDismissNotice = useCallback(() => {
    setNotice(null)
  }, [])

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
      <DashboardHeader user={session.user} onLogout={onLogout} />
      <Box
        component="main"
        sx={{
          width: '100%',
          maxWidth: 1280,
          mx: 'auto',
          px: { xs: 2, md: 3 },
          py: { xs: 3, md: 4 },
        }}
      >
        <Stack spacing={3}>
          <Box>
            <Typography variant="h4">Build Dashboard</Typography>
          </Box>

          <GenerateBuildForm isBuildActive={Boolean(activeUuid)} onGenerate={handleGenerateBuild} />
          <BuildSummaryCards records={records} />

          <Box
            sx={{
              display: 'grid',
              gap: 3,
              gridTemplateColumns: { xs: '1fr', lg: 'minmax(280px, 360px) 1fr' },
              alignItems: 'start',
            }}
          >
            <DownloadBuildSelect
              records={records}
              downloadingUuid={downloadingUuid}
              onDownload={handleDownloadBuild}
            />
            <BuildLogPanel activeUuid={activeUuid} events={streamEvents} />
          </Box>

          <BuildRecordsSection
            records={records}
            isLoading={isLoadingRecords}
            error={recordsError}
            downloadingUuid={downloadingUuid}
            onDownload={handleDownloadBuild}
            onRefresh={loadRecords}
          />
        </Stack>
      </Box>
      <DashboardSnackbar notice={notice} onClose={handleDismissNotice} />
    </Box>
  )
}